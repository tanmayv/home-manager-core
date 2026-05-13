import time
import logging
import os
import json
import subprocess
import state
import tmux_util

POLL_INTERVAL = int(os.environ.get("POLL_INTERVAL", 5))

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
            
        # Consider dead only if it's a zombie. 
        # We don't care about PPID=1 (orphans) because agents might persist 
        # even if their wrapper dies, and we want to keep tracking them.
        if state_char == "Z":
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

def background_monitor():
    """Periodically checks process health and scrapes panes for status."""
    logging.info("Starting background monitor...")
    while True:
        time.sleep(POLL_INTERVAL)
        to_remove = []
        
        agents_snapshot = state.get_all_agents()
        active_panes = tmux_util.list_panes()
        active_pane_ids = [p["pane_id"] for p in active_panes]
            
        for name, info in agents_snapshot.items():
            pane_id = info.get("tmux_pane")
            
            # Acknowledgment logic
            if info.get("status") == "waiting":
                pane_info = next((p for p in active_panes if p["pane_id"] == pane_id), None)
                if pane_info and pane_info.get("pane_active"):
                    logging.info(f"Agent {name} acknowledged by user (pane active). Transitioning to idle.")
                    state.update_agent(name, status="idle")
                    info["status"] = "idle"
                    
            if pane_id and pane_id not in active_pane_ids:
                logging.info(f"Pane {pane_id} for agent {name} no longer exists.")
                to_remove.append(name)
                continue
            wrapper_pid = info.get("wrapper_pid")
            pid = info.get("pid")
            
            wrapper_alive = wrapper_pid and is_process_alive(wrapper_pid)
            child_alive = pid and is_process_alive(pid)

            # Update child PID if not already known, or recover if the tracked child died
            if wrapper_pid and (not info.get("pid") or (pid and not child_alive)):
                try:
                    out = subprocess.check_output(["pgrep", "-P", str(wrapper_pid)], timeout=1).decode("utf-8").strip()
                    if out:
                        actual_pid = int(out.split()[0])
                        state.update_agent(name, pid=actual_pid)
                        pid = actual_pid
                        child_alive = is_process_alive(actual_pid)
                except Exception as e:
                    logging.debug(f"Failed to pgrep child PID for {name}: {e}")

            # If wrapper/child tracking is stale, fall back to inspecting the pane's tty.
            if pane_id and ((wrapper_pid and not wrapper_alive and not child_alive) or (pid and not child_alive)):
                proc = state.discover_agent_process(pane_id, info.get("agent_cmd"))
                if proc:
                    logging.info(f"Recovered live pane process for {name}: PID {proc['pid']} ({proc['comm']})")
                    state.update_agent(name, pid=proc["pid"], wrapper_pid=None)
                    pid = proc["pid"]
                    child_alive = True
                    wrapper_pid = None

            if wrapper_pid:
                if not wrapper_alive and not child_alive:
                    to_remove.append(name)
                    continue
            else:
                # Spawning agent timeout check
                if info.get("status") == "spawning":
                    spawn_time = info.get("timestamp", 0)
                    if time.time() - spawn_time > 60:
                        to_remove.append(name)
                        continue
                # Recovered agent fallback
                elif pid and not child_alive:
                    to_remove.append(name)
                    continue
            
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
                    state.clear_inbox(name)
                except IOError as e:
                    logging.error(f"Failed to flush inbox for {name}: {e}")

        if to_remove:
            for name in to_remove:
                logging.info(f"Removing dead agent: {name}")
                state.delete_agent(name)
