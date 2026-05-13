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

def set_agent_id(pane_id, agent_id, socket_path=None):
    cmd = ["tmux"]
    if socket_path:
        cmd.extend(["-S", socket_path])
    cmd.extend(["set-option", "-p", "-t", pane_id, "@agent_id", agent_id])
    enqueue_tmux_cmd(cmd)


def set_agent_uuid(pane_id, uuid, socket_path=None):
    cmd = ["tmux"]
    if socket_path:
        cmd.extend(["-S", socket_path])
    cmd.extend(["set-option", "-p", "-t", pane_id, "@agent_uuid", uuid])
    enqueue_tmux_cmd(cmd)


def list_panes():
    """Lists panes with ID, agent identity, type, cmd, and active state."""
    try:
        out = run_tmux_cmd(["list-panes", "-a", "-F", "#{pane_id}|#{@agent_name}|#{@agent_id}|#{@agent_uuid}|#{@agent_type}|#{@agent_cmd}|#{pane_active}"])
        panes = []
        if out:
            for line in out.split("\n"):
                parts = line.split('|')
                if len(parts) < 7:
                    continue
                pane_info = {
                    "pane_id": parts[0],
                    "agent_name": parts[1] if parts[1] else None,
                    "agent_id": parts[2] if parts[2] else (parts[3] if parts[3] else None),
                    "agent_uuid": parts[3] if parts[3] else None,
                    "agent_type": parts[4] if parts[4] else "unknown",
                    "agent_cmd": parts[5] if parts[5] else None,
                    "pane_active": (parts[6] == "1")
                }
                panes.append(pane_info)
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

def set_agent_name_sync(pane_id, name, socket_path=None):
    cmd = ["set-option", "-p", "-t", pane_id, "@agent_name", name]
    if socket_path:
        run_tmux_cmd(["-S", socket_path] + cmd)
    else:
        run_tmux_cmd(cmd)

def unset_agent_name(pane_id, socket_path=None):
    cmd = ["tmux"]
    if socket_path:
        cmd.extend(["-S", socket_path])
    cmd.extend(["set-option", "-p", "-u", "-t", pane_id, "@agent_name"])
    enqueue_tmux_cmd(cmd)

def set_pane_title(pane_id, title, socket_path=None):
    cmd = ["tmux"]
    if socket_path:
        cmd.extend(["-S", socket_path])
    cmd.extend(["select-pane", "-t", pane_id, "-T", title])
    enqueue_tmux_cmd(cmd)

def set_pane_title_sync(pane_id, title, socket_path=None):
    cmd = ["select-pane", "-t", pane_id, "-T", title]
    if socket_path:
        run_tmux_cmd(["-S", socket_path] + cmd)
    else:
        run_tmux_cmd(cmd)

def unset_pane_title(pane_id, socket_path=None):
    cmd = ["tmux"]
    if socket_path:
        cmd.extend(["-S", socket_path])
    cmd.extend(["select-pane", "-t", pane_id, "-T", ""])
    enqueue_tmux_cmd(cmd)

def send_keys(pane_id, keys, socket_path=None):
    """Sends keys followed by a short delay and Enter to ensure submission."""
    cmd_base = ["tmux"]
    if socket_path:
        cmd_base.extend(["-S", socket_path])
    
    # 1. Send the actual message keys
    enqueue_tmux_cmd(cmd_base + ["send-keys", "-t", pane_id, keys])
    
    # 2. Enqueue a short sleep to allow the terminal/app to process the input buffer
    enqueue_tmux_cmd(["sleep", "0.5"])
    
    # 3. Send the Enter key to submit
    enqueue_tmux_cmd(cmd_base + ["send-keys", "-t", pane_id, "Enter"])

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
