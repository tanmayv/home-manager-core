import threading
import uuid
import logging
import subprocess
import os
import json
import tmux_util

state = {}
state_lock = threading.Lock()

TRANSIENT_COMMS = {
    "ps", "grep", "pgrep", "ls", "cat", "sleep", "which", "sh", "bash", "zsh",
    "fish", "tmux", "home-manager", "nix", "env"
}


def discover_agent_process(pane_id: str, agent_cmd: str | None = None) -> dict | None:
    """Best-effort discovery of the long-lived agent process attached to a pane."""
    info = tmux_util.get_pane_info(pane_id)
    if not info:
        return None

    tty = info["tty"]
    shell_pid = info["pid"]
    pts_name = tty.replace("/dev/", "")

    try:
        out = subprocess.check_output(
            ["ps", "-t", pts_name, "-o", "pid=,ppid=,comm=,args="],
            timeout=2,
        ).decode("utf-8").strip()
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        return None

    proc_list = []
    for line in out.split("\n"):
        parts = line.strip().split(None, 3)
        if len(parts) < 3:
            continue
        pid = int(parts[0])
        ppid = int(parts[1])
        comm = parts[2]
        args = parts[3] if len(parts) > 3 else comm
        proc_list.append({"pid": pid, "ppid": ppid, "comm": comm, "args": args})

    candidates = [p for p in proc_list if p["pid"] != shell_pid and p["comm"] not in TRANSIENT_COMMS]
    if not candidates:
        return None

    expected_patterns = {
        "jetski": ["cli", "jetski"],
        "gemini": ["gemini"],
        "pi": ["pi", "pi-coding-agent", "@earendil-works/pi-coding-agent"],
    }.get(agent_cmd, [])

    if expected_patterns:
        for proc in reversed(candidates):
            haystack = f'{proc["comm"]} {proc["args"]}'.lower()
            if any(pattern in haystack for pattern in expected_patterns):
                return proc

    return candidates[-1]


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
                proc = discover_agent_process(pane_id, agent_cmd)
                if info and proc:
                    session = info["session"]
                    agent_pid = proc["pid"]
                    discovered_cmd = proc["comm"]
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
