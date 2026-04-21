import json
import logging
import os
import socket
import sys

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s', stream=sys.stderr)
POLL_INTERVAL = int(os.environ.get("POLL_INTERVAL", 5))
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
    except Exception:
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
                if agent_name and agent_name.startswith("minimal-cloudtop-agent-"):
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
                                    "waiting_approval": False
                                }
                            logging.info(f"Recovered agent {agent_name} with PID {agent_pid}")
                    except Exception as e:
                        logging.error(f"Error recovering agent {agent_name}: {e}")
    except Exception as e:
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
            if wrapper_pid and not is_process_alive(wrapper_pid):
                to_remove.append(name)
                continue
            elif not wrapper_pid:
                # Recovered agent fallback! Check PID directly!
                pid = info.get("pid")
                if pid and not is_process_alive(pid):
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

        if to_remove:
            with state_lock:
                for name in to_remove:
                    logging.info(f"Removing dead agent: {name}")
                    if name in state:
                        del state[name]

def handle_client(conn):
    try:
        conn.settimeout(2.0) # Safety timeout for reads
        data = conn.recv(4096)
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
            suggested_name = params.get("suggested_name")
            if session and tmux_pane and wrapper_pid and tmux_socket:
                with state_lock:
                    if suggested_name and suggested_name not in state:
                        agent_name = suggested_name
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
                        "waiting_approval": False
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
            if session and command:
                with state_lock:
                    num = 1
                    while f"{session}-agent-{num}" in state:
                        num += 1
                    agent_name = f"{session}-agent-{num}"
                
                tmux_cmd = ["tmux"]
                if target_pane:
                    tmux_cmd.extend(["split-window", "-t", target_pane])
                else:
                    tmux_cmd.extend(["split-window"])
                
                full_cmd = f"env SUGGESTED_AGENT_NAME={agent_name} agent-wrapper {command}"
                tmux_cmd.append(full_cmd)
                
                try:
                    subprocess.run(tmux_cmd, check=True, capture_output=True)
                    result = agent_name
                except subprocess.CalledProcessError as e:
                    error = {"code": -32603, "message": f"Failed to spin agent: {e.stderr.decode()}"}
            else:
                error = {"code": -32602, "message": "Invalid params"}
        elif method == "send_message":
            sender_name = params.get("sender_name")
            agent_name = params.get("agent_name")
            msg = params.get("message")
            
            if sender_name and agent_name and msg:
                with state_lock:
                    if agent_name in state:
                        info = state[agent_name]
                        full_msg = f"From {sender_name}: {msg}"
                        # Queue the slow tmux interaction to keep this thread responsive
                        task_queue.put({'cmd': ["tmux", "-S", info["tmux_socket"], "send-keys", "-t", info["tmux_pane"], full_msg, "Enter"]})
                        result = True
                    else:
                        error = {"code": -32602, "message": "Target agent not found"}
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
    except Exception as e:
        logging.error(f"Error handling client: {e}")
    finally:
        conn.close()

def main():
    os.makedirs(os.path.dirname(SOCKET_PATH), exist_ok=True)
    if os.path.exists(SOCKET_PATH):
        os.remove(SOCKET_PATH)

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
        except Exception as e:
            logging.error(f"Server accept error: {e}")
            time.sleep(1)

if __name__ == "__main__":
    main()
