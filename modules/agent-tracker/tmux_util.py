import subprocess
import logging
import threading
import queue
import sys

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s', stream=sys.stderr)

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

def enqueue_tmux_cmd(cmd):
    """Enqueues a tmux command for background execution."""
    task_queue.put({'cmd': cmd})

def run_tmux_cmd(cmd, timeout=5):
    """Helper to run tmux commands synchronously."""
    try:
        result = subprocess.run(["tmux"] + cmd, check=True, capture_output=True, timeout=timeout)
        return result.stdout.decode("utf-8").strip()
    except subprocess.CalledProcessError as e:
        logging.error(f"Tmux command failed: {e} - {e.stderr.decode('utf-8')}")
        raise
    except Exception as e:
        logging.error(f"Unexpected error running tmux command: {e}")
        raise

def list_panes():
    """Lists panes with ID and agent name."""
    try:
        out = run_tmux_cmd(["list-panes", "-a", "-F", "#{pane_id} #{@agent_name}"])
        panes = []
        if out:
            for line in out.split("\n"):
                parts = line.split()
                if len(parts) >= 2:
                    panes.append({"pane_id": parts[0], "agent_name": parts[1]})
                elif len(parts) == 1:
                    panes.append({"pane_id": parts[0], "agent_name": None})
        return panes
    except Exception as e:
        logging.error(f"Failed to list panes: {e}")
        return []

def get_pane_info(pane_id):
    """Gets tty, session, and shell pid for a pane."""
    try:
        out = run_tmux_cmd(["display-message", "-p", "-t", pane_id, "#{pane_tty} #S #{pane_pid}"])
        parts = out.split()
        if len(parts) >= 3:
            return {"tty": parts[0], "session": parts[1], "pid": int(parts[2])}
    except Exception as e:
        logging.error(f"Failed to get pane info for {pane_id}: {e}")
    return None

def set_agent_name(pane_id, name, socket_path=None):
    cmd = ["tmux"]
    if socket_path:
        cmd.extend(["-S", socket_path])
    cmd.extend(["set-option", "-p", "-t", pane_id, "@agent_name", name])
    enqueue_tmux_cmd(cmd)

def set_pane_title(pane_id, title, socket_path=None):
    cmd = ["tmux"]
    if socket_path:
        cmd.extend(["-S", socket_path])
    cmd.extend(["select-pane", "-t", pane_id, "-T", title])
    enqueue_tmux_cmd(cmd)

def send_keys(pane_id, keys, socket_path=None):
    cmd = ["tmux"]
    if socket_path:
        cmd.extend(["-S", socket_path])
    cmd.extend(["send-keys", "-t", pane_id, keys, "Enter"])
    enqueue_tmux_cmd(cmd)

def spin_agent(agent_name, command, target_pane=None):
    import shlex
    tmux_cmd = ["tmux"]
    if target_pane:
        tmux_cmd.extend(["split-window", "-t", target_pane])
    else:
        tmux_cmd.extend(["split-window"])
    
    tmux_cmd.extend(["-e", f"SUGGESTED_AGENT_NAME={agent_name}"])
    import os
    if "AGENT_TRACKER_SOCKET" in os.environ:
        tmux_cmd.extend(["-e", f"AGENT_TRACKER_SOCKET={os.environ['AGENT_TRACKER_SOCKET']}"])
    
    quoted_parts = [shlex.quote(part) for part in shlex.split(command)]
    full_cmd = f"agent-wrapper {' '.join(quoted_parts)}"
    tmux_cmd.append(full_cmd)
    
    try:
        subprocess.run(tmux_cmd, check=True, capture_output=True)
    except subprocess.CalledProcessError as e:
        logging.error(f"Tmux split-window failed: {e.stderr.decode()}")
        raise
