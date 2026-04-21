import threading
import uuid
import logging
import subprocess
import os
import json
import tmux_util

state = {}
state_lock = threading.Lock()

def init_state():
    """Recovers existing agents by querying tmux panes."""
    logging.info("Initializing state from tmux panes...")
    panes = tmux_util.list_panes()
    for pane in panes:
        pane_id = pane["pane_id"]
        agent_name = pane["agent_name"]
        if agent_name:
            logging.info(f"Found recovered agent: {agent_name} in pane {pane_id}")
            try:
                info = tmux_util.get_pane_info(pane_id)
                if info:
                    tty = info["tty"]
                    session = info["session"]
                    shell_pid = info["pid"]
                    
                    pts_name = tty.replace("/dev/", "")
                    try:
                        out_pids = subprocess.check_output(["pgrep", "-t", pts_name]).decode("utf-8").strip()
                        pids = [int(p) for p in out_pids.split("\n") if p]
                    except subprocess.CalledProcessError:
                        pids = []
                        
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
            except Exception as e:
                logging.error(f"Error recovering agent {agent_name}: {e}")

def get_all_agents():
    with state_lock:
        return {k: v.copy() for k, v in state.items()}

def get_agent(name):
    with state_lock:
        return state.get(name, None)

def set_agent(name, info):
    with state_lock:
        state[name] = info

def delete_agent(name):
    with state_lock:
        if name in state:
            del state[name]

def update_agent(name, **kwargs):
    with state_lock:
        if name in state:
            for k, v in kwargs.items():
                state[name][k] = v
            return True
        return False

def rename_agent(old_name, new_name):
    with state_lock:
        if old_name in state and new_name not in state:
            state[new_name] = state.pop(old_name)
            return True
        return False

def add_message(agent_name, msg_obj):
    with state_lock:
        if agent_name in state:
            if "inbox" not in state[agent_name]:
                state[agent_name]["inbox"] = []
            state[agent_name]["inbox"].append(msg_obj)
            return True
        return False

def clear_inbox(agent_name):
    with state_lock:
        if agent_name in state:
            state[agent_name]["inbox"] = []
            return True
        return False
