import base64
import binascii
import json
import logging
import socket
import state
import tmux_util
import registry_client
import datetime
import time
import os
import uuid
import subprocess
import struct
import re

BUFFER_SIZE = 4096
LOCAL_HOSTNAME = os.environ.get("AGENT_TRACKER_HOSTNAME", socket.gethostname())


class DeliveryTargetNotFound(ValueError):
    pass


class DeliveryValidationError(ValueError):
    pass


def _utc_now_isoformat() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _is_uuid(value: str) -> bool:
    try:
        uuid.UUID(value)
        return True
    except (ValueError, TypeError, AttributeError):
        return False


def _generate_unique_agent_name(name: str, session: str = None) -> str:
    agents = state.get_all_agents()
    if name:
        agent_name = name
        base_name = name
        num = 1
        m = re.match(r'^(.*)-(\d+)$', name)
        if m:
            base_name = m.group(1)
            num = int(m.group(2))
            if not (state.get_agent_id_by_name(agent_name) and (state.get_agent(agent_name) or {}).get("status") != "spawning"):
                return agent_name
            num += 1
            agent_name = f"{base_name}-{num}"

        while state.get_agent_id_by_name(agent_name) and (state.get_agent(agent_name) or {}).get("status") != "spawning":
            num += 1
            agent_name = f"{base_name}-{num}"
        return agent_name
    else:
        num = 1
        while f"{session}-agent-{num}" in agents:
            num += 1
        return f"{session}-agent-{num}"


def _best_effort_update_tmux_metadata(tmux_pane, agent_name, agent_id, agent_type, agent_cmd, tmux_socket):
    """Persist restart-recovery metadata in tmux without making registration depend on tmux."""
    try:
        tmux_util.set_agent_id(tmux_pane, agent_id, tmux_socket)
        tmux_util.set_agent_uuid(tmux_pane, agent_id, tmux_socket)
        tmux_util.set_agent_name(tmux_pane, agent_name, tmux_socket)
        tmux_util.set_agent_type(tmux_pane, agent_type or "unknown", tmux_socket)
        tmux_util.set_agent_cmd(tmux_pane, agent_cmd or "unknown", tmux_socket)
        tmux_util.set_pane_title(tmux_pane, agent_name, tmux_socket)
    except Exception as e:
        logging.warning("failed to update tmux metadata for agent %s pane %s: %s", agent_name, tmux_pane, e)


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
    existing_name_for_id = state.get_agent_name_by_id(agent_id)

    # Remove any existing agent for the same pane to prevent duplicates.
    for existing_name, info in list(agents.items()):
        if info.get("tmux_pane") == tmux_pane and existing_name != existing_name_for_id:
            logging.info(f"Removing existing agent {existing_name} for pane {tmux_pane} before re-registering")
            state.delete_agent(existing_name)
            agents = state.get_all_agents()

    if existing_name_for_id:
        agent_name = existing_name_for_id
    else:
        agent_name = _generate_unique_agent_name(name, session)
        
    existing_info = state.get_agent(existing_name_for_id) if existing_name_for_id else None
    state.set_agent(agent_name, {
        **(existing_info or {}),
        "session": session,
        "tmux_pane": tmux_pane,
        "wrapper_pid": wrapper_pid,
        "tmux_socket": tmux_socket,
        "pid": (existing_info or {}).get("pid"),
        "status": (existing_info or {}).get("status", "idle"),
        "waiting_approval": (existing_info or {}).get("waiting_approval", False),
        "agent_id": agent_id,
        "uuid": agent_id,
        "agent_type": agent_type or (existing_info or {}).get("agent_type", "unknown"),
        "agent_cmd": agent_cmd or (existing_info or {}).get("agent_cmd", "unknown"),
        "last_heartbeat": time.time(),
        "recovered_at": None,
        "pending_notifications": (existing_info or {}).get("pending_notifications", [])
    })
    
    _best_effort_update_tmux_metadata(tmux_pane, agent_name, agent_id, agent_type, agent_cmd, tmux_socket)
    
    return agent_name

def handle_list(params: dict, caller_pid: int = None) -> dict:
    """Returns all agents in state, marking the caller if identified."""
    agents = state.get_all_agents()
    caller_name = _identify_agent(params, caller_pid)
    
    if caller_name and caller_name in agents:
        agents[caller_name]["is_this_me"] = True
        
    return agents

def _is_agent_waiting(info: dict) -> bool:
    """Returns True if the agent is actively busy or waiting for approval."""
    busy_statuses = {"working", "waiting", "spawning"}
    return info.get("status") in busy_statuses or info.get("waiting_approval", False)

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
        
    kwargs = {k: v for k, v in params.items() if k not in ["agent_id", "agent_name", "tmux_pane"]}
    if state.update_agent(agent_name, **kwargs):
        _flush_notifications(agent_name)
        if "status" in kwargs:
            registry_client.push_agent_update(state.get_agent(agent_name)["agent_id"], kwargs["status"])
        return True
    raise ValueError(f"Agent '{agent_name}' not found")


def handle_heartbeat(params: dict, caller_pid: int = None) -> bool:
    """Records a liveness heartbeat for an identified agent."""
    agent_name = _identify_agent(params, caller_pid)
    if not agent_name:
        raise ValueError("Agent not identified")

    kwargs = {k: v for k, v in params.items() if k not in ["agent_id", "agent_name"]}
    kwargs["last_heartbeat"] = time.time()
    kwargs["recovered_at"] = None
    if state.update_agent(agent_name, **kwargs):
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
    
    caller_name = _identify_agent(params, caller_pid)
    
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
            agent_name = state.get_agent_name_by_pane(tmux_pane)
                    
    if not agent_name:
        raise ValueError("Agent not identified")
        
    info = state.get_agent(agent_name)
    if not info:
        raise ValueError(f"Agent '{agent_name}' not found")
        
    logging.info(f"Unregistering agent: {agent_name}")
    
    # Remove inbox file
    uuid_str = info.get("uuid") or agent_name
    inbox_file = os.path.join(state.INBOX_DIR, f"{uuid_str}.inbox")
    if os.path.exists(inbox_file):
        try:
            os.remove(inbox_file)
        except OSError as e:
            logging.error(f"Failed to remove inbox file for {agent_name}: {e}")
            
    state.delete_agent(agent_name)
    return True

def _resolve_target_agent_name(params: dict) -> str | None:
    """Resolves a target agent by explicit agent_id first, then display name."""
    agent_id = params.get("agent_id")
    if agent_id:
        resolved_name = state.get_agent_name_by_id(agent_id)
        if resolved_name:
            return resolved_name

    agent_name = params.get("agent_name")
    if agent_name and state.get_agent(agent_name):
        return agent_name

    return None


def handle_spin_agent(params: dict) -> str:
    """Spins a new agent in a new tmux pane."""
    session = params.get("session")
    command = params.get("command")
    target_pane = params.get("target_pane")
    name = params.get("name")
    
    if not (session and command and name):
        raise ValueError("Invalid params")
        
    agent_name = _generate_unique_agent_name(name, session)
        
    state.set_agent(agent_name, {"status": "spawning", "timestamp": time.time()})
    
    try:
        tmux_util.spin_agent(agent_name, command, target_pane)
        return agent_name
    except Exception as e:
        state.delete_agent(agent_name)
        raise RuntimeError(f"Failed to spin agent: {e}")

def deliver_local_message(target_name_or_id: str, msg_obj: dict, notify_sender: str | None = None) -> str:
    """Writes a message to a local agent inbox and triggers/queues notification."""
    info = state.get_agent(target_name_or_id)
    if not info:
        raise DeliveryTargetNotFound("Target agent not found")

    current_name = state.get_agent_name_by_id(info["agent_id"]) or target_name_or_id
    uuid_str = info.get("uuid") or current_name
    inbox_file = os.path.join(state.INBOX_DIR, f"{uuid_str}.inbox")
    notify_sender = notify_sender or msg_obj.get("sender", "unknown")
    attach_dir = None
    msg_id = msg_obj.get("message_id")

    try:
        if msg_id and os.path.exists(inbox_file):
            with open(inbox_file, "r") as f:
                for line in f:
                    if not line.strip():
                        continue
                    try:
                        if json.loads(line).get("message_id") == msg_id:
                            logging.info(f"Skipping duplicate delivery {msg_id} for {current_name}")
                            return current_name
                    except json.JSONDecodeError:
                        continue

        attachments = []
        if msg_obj.get("attachments"):
            msg_id = msg_id or str(uuid.uuid4())
            attach_dir = os.path.join(state.INBOX_DIR, "attachments", uuid_str, msg_id)
            os.makedirs(attach_dir, exist_ok=True)
            seen_names = set()
            for att in msg_obj["attachments"]:
                raw_name = att.get("name")
                safe_name = os.path.basename(raw_name or "")
                if not safe_name or "content_b64" not in att:
                    raise DeliveryValidationError("invalid attachments")
                if safe_name in seen_names:
                    raise DeliveryValidationError("duplicate attachment name")
                seen_names.add(safe_name)
                try:
                    content = base64.b64decode(att["content_b64"], validate=True)
                except (binascii.Error, ValueError) as e:
                    raise DeliveryValidationError(f"invalid attachment payload: {e}")
                path = os.path.join(attach_dir, safe_name)
                with open(path, "wb") as af:
                    af.write(content)
                attachments.append({
                    "name": safe_name,
                    "path": path,
                    "content_type": att.get("content_type", "application/octet-stream"),
                    "size": os.path.getsize(path),
                })
            msg_obj = {**msg_obj, "message_id": msg_id, "attachments": attachments}

        os.makedirs(os.path.dirname(inbox_file), exist_ok=True)
        with open(inbox_file, "a") as f:
            f.write(json.dumps(msg_obj) + "\n")

        if _is_agent_waiting(info):
            logging.info(f"Queuing notification for {current_name} from {notify_sender} (agent is busy)")
            pending = info.get("pending_notifications", [])
            pending.append(notify_sender)
            state.update_agent(current_name, pending_notifications=pending)
        else:
            tmux_util.send_keys(info["tmux_pane"], f"New message in inbox from {notify_sender}", info["tmux_socket"])
        return current_name
    except DeliveryValidationError:
        if attach_dir and os.path.isdir(attach_dir):
            for root, _, files in os.walk(attach_dir, topdown=False):
                for name in files:
                    os.remove(os.path.join(root, name))
                os.rmdir(root)
        raise
    except OSError as e:
        if attach_dir and os.path.isdir(attach_dir):
            for root, _, files in os.walk(attach_dir, topdown=False):
                for name in files:
                    os.remove(os.path.join(root, name))
                os.rmdir(root)
        logging.error(f"Failed to write to inbox file for {target_name_or_id}: {e}")
        raise RuntimeError(f"Failed to send message: {e}")


def handle_send_message(params: dict, caller_pid: int = None) -> bool:
    """Sends a message locally or routes it remotely via the registry when target_address is hostname-qualified."""
    sender_name = params.get("sender_name") or _identify_agent(params, caller_pid) or "cli-user"
    msg = params.get("message")
    attachments = params.get("attachments")
    target_address = params.get("target_address")

    if target_address and "/" in target_address:
        hostname, target = target_address.split("/", 1)
        if hostname not in {"local", LOCAL_HOSTNAME}:
            sender_info = state.get_agent(params.get("sender_id") or sender_name) or {}
            status, body = registry_client.send_remote_message(
                sender_name,
                sender_info.get("agent_id") or params.get("sender_id"),
                registry_client.TRACKER_ID,
                hostname,
                target,
                msg,
                attachments,
            )
            if status == 202:
                return True
            raise RuntimeError(f"Remote delivery failed: {(body or {}).get('message', 'unknown error')}")
        params = {**params, **({"agent_id": target} if _is_uuid(target) else {"agent_name": target})}

    agent_name = _resolve_target_agent_name(params)
    if not agent_name or (not msg and not attachments):
        raise ValueError("Invalid params")

    current_name = state.get_agent_name_by_id(state.get_agent(agent_name)["agent_id"])
    warning_msg = None
    if agent_name != current_name:
        warning_msg = f"Note: Agent '{agent_name}' was renamed to '{current_name}'."
        logging.info(warning_msg)

    deliver_local_message(agent_name, {
        "sender": sender_name,
        "timestamp": _utc_now_isoformat(),
        "message": msg,
        "attachments": attachments,
        "read": False,
    }, sender_name)
    return {"success": True, "warning": warning_msg} if warning_msg else True

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
    """Identifies the agent name based on params (id/name/pane) or caller PID."""
    agent_id = params.get("sender_id") or params.get("agent_id")
    if agent_id:
        resolved_name = state.get_agent_name_by_id(agent_id)
        if resolved_name:
            return resolved_name

    agent_name = params.get("agent_name")
    if agent_name:
        return agent_name
        
    tmux_pane = params.get("tmux_pane")
    agents = state.get_all_agents()
    
    if tmux_pane:
        resolved_name = state.get_agent_name_by_pane(tmux_pane)
        if resolved_name:
            return resolved_name
                
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
    inbox_file = os.path.join(state.INBOX_DIR, f"{uuid_str}.inbox")
            
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
    "heartbeat": handle_heartbeat,
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
                if method in ["get_inbox", "update_agent", "heartbeat", "send_message", "whoami", "list", "rename", "unregister"]:
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
