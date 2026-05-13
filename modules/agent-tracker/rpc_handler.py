import json
import logging
import socket
import state
import tmux_util
import datetime
import time
import os
import uuid
import subprocess
import struct

BUFFER_SIZE = 4096

def handle_register(params: dict) -> str:
    """Handles agent registration, accepting a stable agent_id when provided."""
    session = params.get("session")
    tmux_pane = params.get("tmux_pane")
    wrapper_pid = params.get("wrapper_pid")
    tmux_socket = params.get("tmux_socket")
    name = params.get("name")
    agent_type = params.get("agent_type", "unknown")
    agent_cmd = params.get("agent_cmd", "unknown")
    agent_id = params.get("agent_id") or str(uuid.uuid4())
    
    if not (session and tmux_pane and wrapper_pid and tmux_socket):
        raise ValueError("Invalid params")
        
    agents = state.get_all_agents()
    
    # Remove any existing agent for the same pane to prevent duplicates
    for existing_name, info in agents.items():
        if info.get("tmux_pane") == tmux_pane:
            logging.info(f"Removing existing agent {existing_name} for pane {tmux_pane} before re-registering")
            state.delete_agent(existing_name)
            # Refresh agents list after deletion
            agents = state.get_all_agents()

    if name:
        num = 1
        agent_name = name
        while agent_name in agents and agents[agent_name].get("status") != "spawning":
            agent_name = f"{name}-{num}"
            num += 1
    else:
        num = 1
        while f"{session}-agent-{num}" in agents:
            num += 1
        agent_name = f"{session}-agent-{num}"
        
    state.set_agent(agent_name, {
        "session": session, 
        "tmux_pane": tmux_pane, 
        "wrapper_pid": wrapper_pid, 
        "tmux_socket": tmux_socket, 
        "pid": None,
        "status": "idle",
        "waiting_approval": False,
        "agent_id": agent_id,
        "uuid": agent_id,
        "agent_type": agent_type,
        "agent_cmd": agent_cmd,
        "pending_notifications": []
    })
    
    # Persist both new and legacy identity keys in tmux during migration.
    tmux_util.set_agent_id(tmux_pane, agent_id, tmux_socket)
    tmux_util.set_agent_uuid(tmux_pane, agent_id, tmux_socket)
    
    return agent_name

def handle_list(params: dict, caller_pid: int = None) -> dict:
    """Returns all agents in state, marking the caller if identified."""
    agents = state.get_all_agents()
    caller_name = _identify_agent(params, caller_pid)
    
    if caller_name and caller_name in agents:
        agents[caller_name]["is_this_me"] = True
        
    return agents

def _is_agent_waiting(info: dict) -> bool:
    """Returns True if the agent is busy or waiting for approval."""
    return info.get("status") != "idle" or info.get("waiting_approval", False)

def _flush_notifications(agent_name: str):
    """Sends all pending notifications for an agent if it is no longer waiting."""
    info = state.get_agent(agent_name)
    if not info or _is_agent_waiting(info):
        return
        
    pending = info.get("pending_notifications", [])
    if not pending:
        return
        
    logging.info(f"Flushing {len(pending)} notifications for {agent_name}")
    # Send each pending notification
    for sender_name in pending:
        notify_msg = f"New message in inbox from {sender_name}"
        tmux_util.send_keys(info["tmux_pane"], notify_msg, info["tmux_socket"])
        
    state.update_agent(agent_name, pending_notifications=[])

def handle_update_agent(params: dict, caller_pid: int = None) -> bool:
    """Updates agent state fields and flushes notifications if it becomes idle."""
    agent_name = _identify_agent(params, caller_pid)
    if not agent_name:
        raise ValueError("Agent not identified")
        
    kwargs = {k: v for k, v in params.items() if k not in ["agent_name", "tmux_pane"]}
    if state.update_agent(agent_name, **kwargs):
        _flush_notifications(agent_name)
        return True
    raise ValueError(f"Agent '{agent_name}' not found")

def handle_rename(params: dict, caller_pid: int = None) -> bool:
    """Renames an agent with safety checks. 
    Users can rename themselves by providing new_name.
    Renaming others requires old_name, new_name, and force=True.
    """
    old_name = params.get("old_name")
    new_name = params.get("new_name")
    force = params.get("force", False)
    
    caller_name = _identify_agent({}, caller_pid)
    
    if not caller_name and not force:
        raise ValueError("Could not identify caller. Use --force and provide old_name to rename.")

    # If old_name is not provided, assume self-rename
    if not old_name:
        old_name = caller_name
        
    if not old_name or not new_name:
        raise ValueError("Invalid params: new_name is required.")

    if old_name != caller_name and not force:
        raise ValueError(f"Cannot rename '{old_name}' (you are '{caller_name}'). Use --force to override.")
        
    logging.info(f"Attempting to rename agent from {old_name} to {new_name}")
    if state.rename_agent(old_name, new_name):
        info = state.get_agent(new_name)
        tmux_pane = info.get("tmux_pane")
        tmux_socket = info.get("tmux_socket")
        logging.info(f"Renamed {old_name} to {new_name} in state. Updating tmux pane {tmux_pane}")
        if tmux_pane:
            try:
                tmux_util.set_agent_name_sync(tmux_pane, new_name, tmux_socket)
                tmux_util.set_pane_title_sync(tmux_pane, new_name, tmux_socket)
                # Force status bar refresh
                subprocess.run(["tmux-status-refresh"], check=False)
            except Exception as e:
                logging.error(f"Failed to update tmux pane for {new_name}: {e}")
        return True
    logging.error(f"Failed to rename {old_name} to {new_name}. Agent not found or new name exists.")
    raise ValueError("Agent not found or new name exists")

def handle_unregister(params: dict, caller_pid: int = None) -> bool:
    """Unregisters an agent from state."""
    agent_name = _identify_agent(params, caller_pid)
    if not agent_name:
        # Try to find by tmux_pane if provided
        tmux_pane = params.get("tmux_pane")
        if tmux_pane:
            agents = state.get_all_agents()
            for name, info in agents.items():
                if info.get("tmux_pane") == tmux_pane:
                    agent_name = name
                    break
                    
    if not agent_name:
        raise ValueError("Agent not identified")
        
    info = state.get_agent(agent_name)
    if not info:
        raise ValueError(f"Agent '{agent_name}' not found")
        
    logging.info(f"Unregistering agent: {agent_name}")
    
    # Remove inbox file
    uuid_str = info.get("uuid") or agent_name
    inbox_file = os.path.join("/tmp/agent-inboxes", f"{uuid_str}.inbox")
    if os.path.exists(inbox_file):
        try:
            os.remove(inbox_file)
        except OSError as e:
            logging.error(f"Failed to remove inbox file for {agent_name}: {e}")
            
    state.delete_agent(agent_name)
    return True

def handle_spin_agent(params: dict) -> str:
    """Spins a new agent in a new tmux pane."""
    session = params.get("session")
    command = params.get("command")
    target_pane = params.get("target_pane")
    name = params.get("name")
    
    if not (session and command and name):
        raise ValueError("Invalid params")
        
    agents = state.get_all_agents()
    num = 1
    agent_name = name
    while agent_name in agents:
        agent_name = f"{name}-{num}"
        num += 1
        
    state.set_agent(agent_name, {"status": "spawning", "timestamp": time.time()})
    
    try:
        tmux_util.spin_agent(agent_name, command, target_pane)
        return agent_name
    except Exception as e:
        state.delete_agent(agent_name)
        raise RuntimeError(f"Failed to spin agent: {e}")

def handle_send_message(params: dict, caller_pid: int = None) -> bool:
    """Sends a message to an agent by adding it directly to its inbox file, queuing notification if busy."""
    sender_name = params.get("sender_name")
    if not sender_name:
        sender_name = _identify_agent({}, caller_pid)
    
    if not sender_name:
        sender_name = "cli-user"
        
    agent_name = params.get("agent_name")
    msg = params.get("message")
    
    if not (agent_name and msg):
        raise ValueError("Invalid params")
        
    info = state.get_agent(agent_name)
    if not info:
        raise ValueError("Target agent not found")

    msg_obj = {
        "sender": sender_name,
        "timestamp": datetime.datetime.utcnow().isoformat(),
        "message": msg,
        "read": False
    }
    
    uuid_str = info.get("uuid") or agent_name
    inbox_file = os.path.join("/tmp/agent-inboxes", f"{uuid_str}.inbox")
    
    try:
        os.makedirs(os.path.dirname(inbox_file), exist_ok=True)
        with open(inbox_file, "a") as f:
            f.write(json.dumps(msg_obj) + "\n")
            
        if _is_agent_waiting(info):
            logging.info(f"Queuing notification for {agent_name} from {sender_name} (agent is busy)")
            pending = info.get("pending_notifications", [])
            pending.append(sender_name)
            state.update_agent(agent_name, pending_notifications=pending)
        else:
            notify_msg = f"New message in inbox from {sender_name}"
            tmux_util.send_keys(info["tmux_pane"], notify_msg, info["tmux_socket"])
        return True
    except IOError as e:
        logging.error(f"Failed to write to inbox file for {agent_name}: {e}")
        raise RuntimeError(f"Failed to send message: {e}")

def _read_and_update_inbox_file(inbox_file: str, clear: bool, last_n: int = None) -> dict:
    """Reads the inbox file, handles unread/history/last_n messages, marks them as read, and rewrites the file."""
    if not os.path.exists(inbox_file):
        return {"mode": "history", "messages": []}
        
    try:
        all_messages = []
        with open(inbox_file, "r") as f:
            for line in f:
                if line.strip():
                    try:
                        all_messages.append(json.loads(line))
                    except json.JSONDecodeError:
                        pass
        
        mode = "unread"
        result_messages = []
        
        if last_n is not None:
            mode = "last_n"
            result_messages = all_messages[-last_n:] if last_n > 0 else []
            for msg in result_messages:
                msg["read"] = True
        else:
            unread_messages = [m for m in all_messages if not m.get("read", False)]
            if unread_messages:
                mode = "unread"
                result_messages = unread_messages
                for msg in unread_messages:
                    msg["read"] = True
            else:
                mode = "history"
                result_messages = all_messages[-5:]
                
        if clear:
            os.remove(inbox_file)
        else:
            with open(inbox_file, "w") as f:
                for m in all_messages:
                    f.write(json.dumps(m) + "\n")
        return {"mode": mode, "messages": result_messages}
    except IOError as e:
        raise RuntimeError(f"Failed to access inbox file: {e}")


def _identify_agent(params: dict, caller_pid: int = None) -> str:
    """Identifies the agent name based on params (name, pane) or caller PID."""
    agent_name = params.get("agent_name")
    if agent_name:
        return agent_name
        
    tmux_pane = params.get("tmux_pane")
    agents = state.get_all_agents()
    
    if tmux_pane:
        for name, info in agents.items():
            if info.get("tmux_pane") == tmux_pane:
                return name
                
    if caller_pid:
        # Trace up the process tree to find a match with wrapper_pid or pid
        curr_pid = caller_pid
        while curr_pid > 1:
            for name, info in agents.items():
                if info.get("wrapper_pid") == curr_pid or info.get("pid") == curr_pid:
                    return name
            try:
                with open(f"/proc/{curr_pid}/status", "r") as f:
                    for line in f:
                        if line.startswith("PPid:"):
                            curr_pid = int(line.split()[1])
                            break
                    else:
                        break
            except (IOError, ValueError):
                break
    return None


def handle_get_inbox(params: dict, caller_pid: int = None) -> dict:
    """Handles get_inbox RPC call by reading directly from the inbox file."""
    clear = params.get("clear", False)
    last_n = params.get("last_n")
    
    if last_n is not None:
        try:
            last_n = int(last_n)
        except ValueError:
            raise ValueError("last_n must be an integer")
            
    agent_name = _identify_agent(params, caller_pid)
    if not agent_name:
        raise ValueError("Agent not identified. Provide agent_name or run from an agent pane.")
        
    info = state.get_agent(agent_name)
    if not info:
        raise ValueError(f"Agent '{agent_name}' not found")
        
    uuid_str = info.get("uuid") or agent_name
    inbox_file = os.path.join("/tmp/agent-inboxes", f"{uuid_str}.inbox")
            
    return _read_and_update_inbox_file(inbox_file, clear, last_n)


def handle_whoami(params: dict, caller_pid: int = None) -> dict:
    """Returns information about the calling agent."""
    agent_name = _identify_agent(params, caller_pid)
    if not agent_name:
        raise ValueError("Agent not identified. Run from an agent pane or process.")
        
    info = state.get_agent(agent_name)
    if not info:
        raise ValueError(f"Agent '{agent_name}' not found in state.")
        
    return {
        "name": agent_name,
        "agent_id": info.get("agent_id") or info.get("uuid"),
        "uuid": info.get("uuid"),
        "pid": info.get("pid"),
        "pane_id": info.get("tmux_pane")
    }


dispatcher = {
    "register": handle_register,
    "list": handle_list,
    "update_agent": handle_update_agent,
    "rename": handle_rename,
    "spin_agent": handle_spin_agent,
    "send_message": handle_send_message,
    "get_inbox": handle_get_inbox,
    "whoami": handle_whoami,
    "unregister": handle_unregister
}

def handle_client(conn: socket.socket) -> None:
    """Handles a single client connection, reading JSON-RPC request and sending response."""
    try:
        conn.settimeout(2.0)
        
        # Try to get peer credentials (PID)
        caller_pid = None
        try:
            # SO_PEERCRED returns (pid, uid, gid) as 3 integers
            creds = conn.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize('3i'))
            caller_pid, _, _ = struct.unpack('3i', creds)
        except Exception as e:
            logging.debug(f"Failed to get SO_PEERCRED: {e}")

        data = b""
        while True:
            chunk = conn.recv(BUFFER_SIZE)
            if not chunk:
                break
            data += chunk
            
        if not data:
            return
            
        try:
            req = json.loads(data.decode())
        except json.JSONDecodeError:
            return
            
        method = req.get("method")
        params = req.get("params", {})
        req_id = req.get("id")
        
        result = None
        error = None
        
        handler = dispatcher.get(method)
        if handler:
            try:
                # Pass caller_pid to handlers that might need it
                if method in ["get_inbox", "update_agent", "send_message", "whoami", "list", "rename"]:
                    result = handler(params, caller_pid=caller_pid)
                else:
                    result = handler(params)
            except ValueError as e:
                error = {"code": -32602, "message": str(e)}
            except RuntimeError as e:
                error = {"code": -32603, "message": str(e)}
            except Exception as e:
                error = {"code": -32603, "message": f"Internal error: {e}"}
        else:
            error = {"code": -32601, "message": "Method not found"}
            
        resp = {"jsonrpc": "2.0", "id": req_id}
        if error:
            resp["error"] = error
        else:
            resp["result"] = result
            
        conn.sendall(json.dumps(resp).encode())
    except (socket.error, socket.timeout) as e:
        logging.error(f"Socket error handling client: {e}")
    except Exception as e:
        logging.error(f"Unexpected error handling client: {e}")
    finally:
        conn.close()
