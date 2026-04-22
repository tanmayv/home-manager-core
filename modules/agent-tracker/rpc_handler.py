import json
import logging
import socket
import state
import tmux_util
import datetime
import time
import os
import uuid

BUFFER_SIZE = 4096

def handle_register(params: dict) -> str:
    """Handles agent registration. Generates a UUID for the agent."""
    session = params.get("session")
    tmux_pane = params.get("tmux_pane")
    wrapper_pid = params.get("wrapper_pid")
    tmux_socket = params.get("tmux_socket")
    name = params.get("name")
    
    if not (session and tmux_pane and wrapper_pid and tmux_socket):
        raise ValueError("Invalid params")
        
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
        "uuid": str(uuid.uuid4()),
        "inbox": []
    })
    return agent_name

def handle_list(params: dict) -> dict:
    """Returns all agents in state."""
    return state.get_all_agents()

def handle_update_agent(params: dict) -> bool:
    """Updates agent state fields."""
    agent_name = params.get("agent_name")
    if not agent_name:
        raise ValueError("Agent not found")
        
    kwargs = {k: v for k, v in params.items() if k != "agent_name"}
    if state.update_agent(agent_name, **kwargs):
        return True
    raise ValueError("Agent not found")

def handle_rename(params: dict) -> bool:
    """Renames an agent and updates tmux options."""
    old_name = params.get("old_name")
    new_name = params.get("new_name")
    if not (old_name and new_name):
        raise ValueError("Invalid params")
        
    if state.rename_agent(old_name, new_name):
        info = state.get_agent(new_name)
        tmux_pane = info.get("tmux_pane")
        tmux_socket = info.get("tmux_socket")
        if tmux_pane:
            tmux_util.set_agent_name(tmux_pane, new_name, tmux_socket)
            tmux_util.set_pane_title(tmux_pane, new_name, tmux_socket)
        return True
    raise ValueError("Agent not found or new name exists")

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

def handle_send_message(params: dict) -> bool:
    """Sends a message to an agent by adding it to its inbox."""
    sender_name = params.get("sender_name")
    agent_name = params.get("agent_name")
    msg = params.get("message")
    
    if not (sender_name and agent_name and msg):
        raise ValueError("Invalid params")
        
    msg_obj = {
        "sender": sender_name,
        "timestamp": datetime.datetime.utcnow().isoformat(),
        "message": msg,
        "read": False
    }
    
    if state.add_message(agent_name, msg_obj):
        info = state.get_agent(agent_name)
        notify_msg = f"[New message in inbox! Use agent-tracker-ctl read-inbox]"
        tmux_util.send_keys(info["tmux_pane"], notify_msg, info["tmux_socket"])
        return True
    raise ValueError("Target agent not found")

def _read_and_update_inbox_file(inbox_file: str, clear: bool) -> str:
    """Reads the inbox file, filters unread messages, marks them as read, and rewrites the file."""
    if not os.path.exists(inbox_file):
        return "Inbox is empty."
        
    try:
        all_messages = []
        unread_messages = []
        with open(inbox_file, "r") as f:
            for line in f:
                if line.strip():
                    try:
                        msg_obj = json.loads(line)
                        if not msg_obj.get("read", False):
                            unread_messages.append(msg_obj)
                            msg_obj["read"] = True
                        all_messages.append(msg_obj)
                    except json.JSONDecodeError:
                        pass
        
        result = "".join([json.dumps(m) + "\n" for m in unread_messages])
        
        if clear:
            os.remove(inbox_file)
        else:
            with open(inbox_file, "w") as f:
                for m in all_messages:
                    f.write(json.dumps(m) + "\n")
        return result
    except IOError as e:
        raise RuntimeError(f"Failed to access inbox file: {e}")

def handle_get_inbox(params: dict) -> str:
    """Handles get_inbox RPC call. Flushes in-memory messages first."""
    agent_name = params.get("agent_name")
    clear = params.get("clear", False)
    
    if not agent_name:
        raise ValueError("Invalid params")
        
    info = state.get_agent(agent_name)
    if not info:
        raise ValueError("Agent not found")
        
    inbox = info.get("inbox", [])
    uuid_str = info.get("uuid") or agent_name
    inbox_file = os.path.join("/tmp/agent-inboxes", f"{uuid_str}.inbox")
    
    if inbox:
        try:
            os.makedirs(os.path.dirname(inbox_file), exist_ok=True)
            with open(inbox_file, "a") as f:
                for msg_obj in inbox:
                    f.write(json.dumps(msg_obj) + "\n")
            state.clear_inbox(agent_name)
        except IOError as e:
            logging.error(f"Failed to flush inbox on demand for {agent_name}: {e}")
            
    return _read_and_update_inbox_file(inbox_file, clear)

dispatcher = {
    "register": handle_register,
    "list": handle_list,
    "update_agent": handle_update_agent,
    "rename": handle_rename,
    "spin_agent": handle_spin_agent,
    "send_message": handle_send_message,
    "get_inbox": handle_get_inbox
}

def handle_client(conn: socket.socket) -> None:
    """Handles a single client connection, reading JSON-RPC request and sending response."""
    try:
        conn.settimeout(2.0)
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
