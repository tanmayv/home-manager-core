import json
import logging
import os
import socket
import sys
import uuid

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s', stream=sys.stderr)
POLL_INTERVAL = int(os.environ.get("POLL_INTERVAL", 5))
BUFFER_SIZE = 4096
import threading
import queue
import subprocess
import time

SOCKET_PATH = os.path.expanduser("~/.cache/agent-tracker.sock")
state = {}
state_lock = threading.Lock()
# Queue for slow tasks (like tmux interactions) to avoid blocking listener threads
task_queue = queue.Queue()

def tmux_worker():
    """Worker thread for executing tmux commands sequentially."""
    while True:
        task = task_queue.get()
        if task is None: break
        try:
            cmd = task['cmd']
            # Use a reasonable timeout for tmux commands
            subprocess.run(cmd, check=True, capture_output=True, timeout=5)
        except Exception as e:
            logging.error(f"Tmux worker error: {e}")
        finally:
            task_queue.task_done()

# Start tmux worker
threading.Thread(target=tmux_worker, daemon=True).start()

def is_process_alive(pid):
    """Checks if a process is alive. Note: This is Linux-specific due to /proc usage."""
    try:
        state_char = None
        ppid = None
        with open(f"/proc/{pid}/status", "r") as f:
            for line in f:
                if line.startswith("State:"):
                    state_char = line.split()[1]
                elif line.startswith("PPid:"):
                    ppid = int(line.split()[1])
        
        if state_char is None or ppid is None:
            return False
            
        # Consider dead if zombie or orphaned (PPid == 1)
        if state_char == "Z" or ppid == 1:
            return False
        return True
    except FileNotFoundError:
        return False
    except (IOError, ValueError) as e:
        logging.debug(f"Error reading process status for PID {pid}: {e}")
        return False
    except Exception as e:
        logging.debug(f"Unexpected error in is_process_alive for PID {pid}: {e}")
        return False

def init_state():
    """Recovers existing agents by querying tmux panes."""
    logging.info("Initializing state from tmux panes...")
    try:
        out = subprocess.check_output(["tmux", "list-panes", "-a", "-F", "#{pane_id} #{@agent_name}"]).decode("utf-8").strip()
        for line in out.split("\n"):
            parts = line.split()
            if len(parts) >= 2:
                pane_id = parts[0]
                agent_name = parts[1]
                if agent_name:
                    logging.info(f"Found recovered agent: {agent_name} in pane {pane_id}")
                    try:
                        tty = subprocess.check_output(["tmux", "display-message", "-p", "-t", pane_id, "#{pane_tty}"]).decode("utf-8").strip()
                        session = subprocess.check_output(["tmux", "display-message", "-p", "-t", pane_id, "#S"]).decode("utf-8").strip()
                        
                        pts_name = tty.replace("/dev/", "")
                        out_pids = subprocess.check_output(["pgrep", "-t", pts_name]).decode("utf-8").strip()
                        pids = [int(p) for p in out_pids.split("\n") if p]
                        
                        shell_pid = int(subprocess.check_output(["tmux", "display-message", "-p", "-t", pane_id, "#{pane_pid}"]).decode("utf-8").strip())
                        
                        agent_pid = None
                        for p in pids:
                            if p != shell_pid:
                                agent_pid = p
                                break
                                
                        if agent_pid:
                            with state_lock:
                                state[agent_name] = {
                                    "session": session,
                                    "tmux_pane": pane_id,
                                    "pid": agent_pid,
                                    "tmux_socket": "", # Fallback to default
                                    "wrapper_pid": None,
                                    "status": "idle",
                                    "waiting_approval": False,
                                    "uuid": str(uuid.uuid4()),
                                    "inbox": []
                                }
                            logging.info(f"Recovered agent {agent_name} with PID {agent_pid}")
                    except subprocess.CalledProcessError as e:
                        logging.error(f"Error recovering agent {agent_name}: {e}")
    except subprocess.CalledProcessError as e:
        logging.error(f"Error during init_state: {e}")

def background_monitor():
    """Periodically checks process health and scrapes panes for status."""
    while True:
        time.sleep(POLL_INTERVAL)
        to_remove = []
        
        with state_lock:
            agents_snapshot = {name: info.copy() for name, info in state.items()}
            
        for name, info in agents_snapshot.items():
            wrapper_pid = info.get("wrapper_pid")
            pid = info.get("pid")
            
            wrapper_alive = wrapper_pid and is_process_alive(wrapper_pid)
            child_alive = pid and is_process_alive(pid)
            
            if wrapper_pid:
                if not wrapper_alive and not child_alive:
                    to_remove.append(name)
                    continue
            else:
                # Recovered agent fallback
                if pid and not child_alive:
                    to_remove.append(name)
                    continue

            # Update child PID if not already known
            if not info.get("pid") and wrapper_pid:
                try:
                    out = subprocess.check_output(["pgrep", "-P", str(wrapper_pid)], timeout=1).decode("utf-8").strip()
                    if out:
                        actual_pid = int(out.split()[0])
                        with state_lock:
                            if name in state:
                                state[name]["pid"] = actual_pid
                except:
                    pass
            
            # Flush inbox to file
            inbox = info.get("inbox", [])
            if inbox:
                uuid_str = info.get("uuid")
                if not uuid_str:
                    uuid_str = name
                inbox_file = os.path.join("/tmp/agent-inboxes", f"{uuid_str}.inbox")
                try:
                    os.makedirs(os.path.dirname(inbox_file), exist_ok=True)
                    with open(inbox_file, "a") as f:
                        for msg_obj in inbox:
                            f.write(json.dumps(msg_obj) + "\n")
                    with state_lock:
                        if name in state:
                            state[name]["inbox"] = []
                except IOError as e:
                    logging.error(f"Failed to flush inbox for {name}: {e}")

        if to_remove:
            with state_lock:
                for name in to_remove:
                    logging.info(f"Removing dead agent: {name}")
                    if name in state:
                        del state[name]

def handle_client(conn):
    try:
        conn.settimeout(2.0) # Safety timeout for reads
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

        if method == "register":
            session = params.get("session")
            tmux_pane = params.get("tmux_pane")
            wrapper_pid = params.get("wrapper_pid")
            tmux_socket = params.get("tmux_socket")
            name = params.get("name")
            if session and tmux_pane and wrapper_pid and tmux_socket:
                with state_lock:
                    if name:
                        num = 1
                        agent_name = name
                        while agent_name in state and state[agent_name].get("status") != "spawning":
                            agent_name = f"{name}-{num}"
                            num += 1
                    else:
                        num = 1
                        while f"{session}-agent-{num}" in state:
                            num += 1
                        agent_name = f"{session}-agent-{num}"
                    
                    state[agent_name] = {
                        "session": session, 
                        "tmux_pane": tmux_pane, 
                        "wrapper_pid": wrapper_pid, 
                        "tmux_socket": tmux_socket, 
                        "pid": None,
                        "status": "idle",
                        "waiting_approval": False,
                        "uuid": str(uuid.uuid4()),
                        "inbox": []
                    }
                    result = agent_name
            else:
                error = {"code": -32602, "message": "Invalid params"}
        elif method == "list":
            with state_lock:
                result = {k: v.copy() for k, v in state.items()}
        elif method == "update_agent":
            agent_name = params.get("agent_name")
            with state_lock:
                if agent_name in state:
                    for k, v in params.items():
                        if k != "agent_name":
                            state[agent_name][k] = v
                    result = True
                else:
                    error = {"code": -32602, "message": "Agent not found"}
        elif method == "rename":
            old_name = params.get("old_name")
            new_name = params.get("new_name")
            if old_name and new_name:
                with state_lock:
                    if old_name in state:
                        if new_name not in state:
                            state[new_name] = state.pop(old_name)
                            result = True
                            
                            info = state[new_name]
                            tmux_pane = info.get("tmux_pane")
                            tmux_socket = info.get("tmux_socket")
                            if tmux_pane:
                                cmd_opt = ["tmux"]
                                if tmux_socket:
                                    cmd_opt.extend(["-S", tmux_socket])
                                cmd_opt.extend(["set-option", "-p", "-t", tmux_pane, "@agent_name", new_name])
                                task_queue.put({'cmd': cmd_opt})
                                
                                cmd_title = ["tmux"]
                                if tmux_socket:
                                    cmd_title.extend(["-S", tmux_socket])
                                cmd_title.extend(["select-pane", "-t", tmux_pane, "-T", new_name])
                                task_queue.put({'cmd': cmd_title})
                        else:
                            error = {"code": -32602, "message": "New name already exists"}
                    else:
                        error = {"code": -32602, "message": "Agent not found"}
            else:
                error = {"code": -32602, "message": "Invalid params"}
        elif method == "spin_agent":
            session = params.get("session")
            command = params.get("command")
            target_pane = params.get("target_pane")
            name = params.get("name")
            if session and command and name:
                with state_lock:
                    num = 1
                    agent_name = name
                    while agent_name in state:
                        agent_name = f"{name}-{num}"
                        num += 1
                    
                    # Reserve the name
                    state[agent_name] = {"status": "spawning"}
                
                import shlex
                tmux_cmd = ["tmux"]
                if target_pane:
                    tmux_cmd.extend(["split-window", "-t", target_pane])
                else:
                    tmux_cmd.extend(["split-window"])
                
                tmux_cmd.extend(["-e", f"SUGGESTED_AGENT_NAME={agent_name}"])
                
                quoted_parts = [shlex.quote(part) for part in shlex.split(command)]
                full_cmd = f"agent-wrapper {' '.join(quoted_parts)}"
                tmux_cmd.append(full_cmd)
                
                try:
                    subprocess.run(tmux_cmd, check=True, capture_output=True)
                    result = agent_name
                except subprocess.CalledProcessError as e:
                    with state_lock:
                        del state[agent_name] # Remove reserved name on failure
                    error = {"code": -32603, "message": f"Failed to spin agent: {e.stderr.decode()}"}
            else:
                error = {"code": -32602, "message": "Invalid params (name, session, and command are required)"}
        elif method == "send_message":
            sender_name = params.get("sender_name")
            agent_name = params.get("agent_name")
            msg = params.get("message")
            
            if sender_name and agent_name and msg:
                with state_lock:
                    if agent_name in state:
                        import datetime
                        msg_obj = {
                            "sender": sender_name,
                            "timestamp": datetime.datetime.utcnow().isoformat(),
                            "message": msg,
                            "read": False
                        }
                        if "inbox" not in state[agent_name]:
                            state[agent_name]["inbox"] = []
                        state[agent_name]["inbox"].append(msg_obj)
                        
                        info = state[agent_name]
                        notify_msg = f"[New message in inbox! Use agent-tracker-ctl read-inbox]"
                        task_queue.put({'cmd': ["tmux", "-S", info["tmux_socket"], "send-keys", "-t", info["tmux_pane"], notify_msg, "Enter"]})
                        result = True
                    else:
                        error = {"code": -32602, "message": "Target agent not found"}
            else:
                error = {"code": -32602, "message": "Invalid params"}
        elif method == "get_inbox":
            agent_name = params.get("agent_name")
            clear = params.get("clear", False)
            
            if agent_name:
                # Trigger flush first to ensure we get all messages
                with state_lock:
                    if agent_name in state:
                        info = state[agent_name]
                        inbox = info.get("inbox", [])
                        uuid_str = info.get("uuid")
                        if not uuid_str:
                            uuid_str = agent_name
                            
                        inbox_file = os.path.join("/tmp/agent-inboxes", f"{uuid_str}.inbox")
                        
                        if inbox:
                            try:
                                os.makedirs(os.path.dirname(inbox_file), exist_ok=True)
                                with open(inbox_file, "a") as f:
                                    for msg_obj in inbox:
                                        f.write(json.dumps(msg_obj) + "\n")
                                state[agent_name]["inbox"] = []
                            except IOError as e:
                                logging.error(f"Failed to flush inbox on demand for {agent_name}: {e}")
                                
                        # Now read the file
                        logging.info(f"Checking inbox file: {inbox_file}")
                        if os.path.exists(inbox_file):
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
                            except IOError as e:
                                error = {"code": -32603, "message": f"Failed to access inbox file: {e}"}
                        else:
                            result = "Inbox is empty."
                    else:
                        error = {"code": -32602, "message": "Agent not found"}
            else:
                error = {"code": -32602, "message": "Invalid params"}
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

def main():
    os.makedirs(os.path.dirname(SOCKET_PATH), exist_ok=True)
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(SOCKET_PATH)
        logging.error(f"Another instance of agent-tracker is already listening on {SOCKET_PATH}")
        sys.exit(1)
    except ConnectionRefusedError:
        logging.info(f"Stale socket found at {SOCKET_PATH}, removing it.")
        os.remove(SOCKET_PATH)
    except FileNotFoundError:
        pass

    init_state()
    # Start background monitor thread
    threading.Thread(target=background_monitor, daemon=True).start()

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    server.listen(10)
    
    logging.info(f"Agent Tracker listening on {SOCKET_PATH}")

    while True:
        try:
            conn, _ = server.accept()
            # Each connection gets its own thread for parallelism
            threading.Thread(target=handle_client, args=(conn,), daemon=True).start()
        except socket.error as e:
            logging.error(f"Server accept error: {e}")
            time.sleep(1)

if __name__ == "__main__":
    main()
