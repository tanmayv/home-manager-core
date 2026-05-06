import threading
import uuid
import logging
import subprocess
import os
import json
import tmux_util

state = {}
state_lock = threading.Lock()

def init_state() -> None:
    """Recovers existing agents by querying tmux panes."""
    logging.info("Initializing state from tmux panes...")
    panes = tmux_util.list_panes()
    for pane in panes:
        pane_id = pane["pane_id"]
        agent_name = pane["agent_name"]
        agent_uuid = pane["agent_uuid"]
        agent_type = pane.get("agent_type", "unknown")
        agent_cmd = pane.get("agent_cmd")
        if agent_name:
            logging.info(f"Found recovered agent: {agent_name} of type {agent_type} in pane {pane_id}")
            try:
                info = tmux_util.get_pane_info(pane_id)
                if info:
                    tty = info["tty"]
                    session = info["session"]
                    shell_pid = info["pid"]
                    
                    pts_name = tty.replace("/dev/", "")
                    try:
                        out = subprocess.check_output(["ps", "-t", pts_name, "-o", "pid=,comm="]).decode("utf-8").strip()
                        lines = [line.strip().split(None, 1) for line in out.split("\n") if line.strip()]
                        proc_list = [(int(parts[0]), parts[1]) for parts in lines if len(parts) == 2]
                    except subprocess.CalledProcessError:
                        proc_list = []
                        out = "ERROR: ps failed"
                        
                    agent_pid = None
                    discovered_cmd = None
                    transient_comms = ["ps", "grep", "pgrep", "ls", "cat", "sleep", "which", "sh", "bash", "home-manager", "nix"]
                    
                    cmd_mapping = {"jetski": ["cli"], "gemini": ["gemini"]}
                    expected_comms = cmd_mapping.get(agent_cmd, []) if agent_cmd else []
                    
                    for pid, comm in proc_list:
                        if pid != shell_pid and comm not in transient_comms:
                            if expected_comms:
                                if comm in expected_comms:
                                    agent_pid = pid
                                    discovered_cmd = comm
                                    break
                            else:
                                # Fallback to heuristic if no expected commands defined
                                agent_pid = pid
                                discovered_cmd = comm
                                break
                            
                    if agent_pid:
                        resolved_uuid = agent_uuid or str(uuid.uuid4())
                        with state_lock:
                            state[agent_name] = {
                                "session": session,
                                "tmux_pane": pane_id,
                                "pid": agent_pid,
                                "tmux_socket": "", # Fallback to default
                                "wrapper_pid": None,
                                "status": "idle",
                                "waiting_approval": False,
                                "uuid": resolved_uuid,
                                "agent_type": agent_type,
                                "agent_cmd": agent_cmd or discovered_cmd or "unknown",
                                "pending_notifications": []
                            }
                        
                        # If we didn't have a UUID in tmux, persist the new one
                        if not agent_uuid:
                            logging.info(f"Generated new UUID {resolved_uuid} for recovered agent {agent_name}")
                            tmux_util.set_agent_uuid(pane_id, resolved_uuid)
                            
                        logging.info(f"Recovered agent {agent_name} with PID {agent_pid} and UUID {resolved_uuid}")
            except Exception as e:
                logging.error(f"Error recovering agent {agent_name}: {e}")

def get_all_agents() -> dict:
    """Returns a copy of all agents in state."""
    with state_lock:
        return {k: v.copy() for k, v in state.items()}

def get_agent(name: str) -> dict | None:
    """Returns the state of a specific agent."""
    with state_lock:
        return state.get(name, None)

def set_agent(name: str, info: dict) -> None:
    """Sets the state of a specific agent."""
    with state_lock:
        state[name] = info

def delete_agent(name: str) -> None:
    """Deletes an agent from state."""
    with state_lock:
        if name in state:
            del state[name]

def update_agent(name: str, **kwargs) -> bool:
    """Updates specific fields of an agent's state."""
    with state_lock:
        if name in state:
            for k, v in kwargs.items():
                state[name][k] = v
            return True
        return False

def rename_agent(old_name: str, new_name: str) -> bool:
    """Renames an agent in state."""
    with state_lock:
        if old_name == new_name:
            return True
        if old_name in state and new_name not in state:
            state[new_name] = state.pop(old_name)
            return True
        return False
