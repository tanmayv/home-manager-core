import threading
import time
import uuid
import logging
import subprocess
import os
import json
import tmux_util

CACHE_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "agent-tracker")
SOCKET_PATH = os.environ.get("AGENT_TRACKER_SOCKET", os.path.join(CACHE_DIR, "agent-tracker.sock"))
LOCK_PATH = os.path.join(CACHE_DIR, "agent-tracker.lock")
INBOX_DIR = os.path.join(CACHE_DIR, "inboxes")

state = {}  # keyed by stable agent_id
name_index = {}  # agent_name -> agent_id
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
        agent_id = pane.get("agent_id")
        agent_uuid = pane["agent_uuid"]
        agent_type = pane.get("agent_type", "unknown")
        agent_cmd = pane.get("agent_cmd")
        if agent_name:
            logging.info(f"Found recovered agent: {agent_name} of type {agent_type} in pane {pane_id}")
            try:
                info = tmux_util.get_pane_info(pane_id)
                proc = discover_agent_process(pane_id, agent_cmd)
                if info:
                    session = info["session"]
                    agent_pid = proc["pid"] if proc else None
                    discovered_cmd = proc["comm"] if proc else None
                    resolved_agent_id = agent_id or agent_uuid or str(uuid.uuid4())
                    set_agent(agent_name, {
                        "session": session,
                        "tmux_pane": pane_id,
                        "pid": agent_pid,
                        "tmux_socket": "", # Fallback to default
                        "wrapper_pid": None,
                        "status": "unknown",
                        "waiting_approval": False,
                        "agent_id": resolved_agent_id,
                        "uuid": resolved_agent_id,
                        "recovered_at": time.time(),
                        "agent_type": agent_type,
                        "agent_cmd": agent_cmd or discovered_cmd or "unknown",
                        "pending_notifications": []
                    })

                    # If we didn't have an agent_id in tmux, persist the recovered one.
                    if not agent_id:
                        logging.info(f"Generated/recovered agent ID {resolved_agent_id} for agent {agent_name}")
                        tmux_util.set_agent_id(pane_id, resolved_agent_id)
                        tmux_util.set_agent_uuid(pane_id, resolved_agent_id)

                    logging.info(f"Recovered agent {agent_name} with PID {agent_pid} and agent ID {resolved_agent_id}")
            except Exception as e:
                logging.error(f"Error recovering agent {agent_name}: {e}")

def _resolve_agent_id(name_or_id: str) -> str | None:
    if name_or_id in state:
        return name_or_id
    return name_index.get(name_or_id)


def get_all_agents() -> dict:
    """Returns a copy of all agents indexed by display name for compatibility."""
    with state_lock:
        return {
            info["name"]: {k: v for k, v in info.items() if k != "name"}
            for info in state.values()
        }


def get_agent(name_or_id: str) -> dict | None:
    """Returns the state of a specific agent by display name or agent_id."""
    with state_lock:
        agent_id = _resolve_agent_id(name_or_id)
        if not agent_id:
            return None
        info = state.get(agent_id)
        if not info:
            return None
        return {k: v for k, v in info.items() if k != "name"}


def get_agent_name_by_id(agent_id: str) -> str | None:
    """Returns the agent name for a given stable agent_id."""
    with state_lock:
        info = state.get(agent_id)
        return info.get("name") if info else None


def get_agent_id_by_name(name: str) -> str | None:
    """Returns the stable agent_id for a given display name."""
    with state_lock:
        return name_index.get(name)


def get_agent_name_by_pane(tmux_pane: str) -> str | None:
    """Returns the agent name for a given tmux pane."""
    with state_lock:
        for info in state.values():
            if info.get("tmux_pane") == tmux_pane:
                return info.get("name")
    return None


def set_agent(name: str, info: dict) -> None:
    """Sets or upserts an agent keyed by stable agent_id."""
    with state_lock:
        normalized = info.copy()
        agent_id = normalized.get("agent_id") or normalized.get("uuid") or str(uuid.uuid4())
        normalized["agent_id"] = agent_id
        normalized["uuid"] = agent_id
        normalized["name"] = name
        if "aliases" not in normalized:
            normalized["aliases"] = []

        existing = state.get(agent_id)
        if existing:
            normalized["aliases"] = existing.get("aliases", []).copy()
            if existing.get("name") and existing.get("name") != name:
                if existing["name"] not in normalized["aliases"]:
                    normalized["aliases"].append(existing["name"])

        existing_id_for_name = name_index.get(name)
        if existing_id_for_name and existing_id_for_name != agent_id:
            state.pop(existing_id_for_name, None)
            name_index.pop(name, None)

        state[agent_id] = normalized
        name_index[name] = agent_id
        for alias in normalized["aliases"]:
            name_index[alias] = agent_id


def delete_agent(name_or_id: str) -> None:
    """Deletes an agent from state by display name or agent_id."""
    with state_lock:
        agent_id = _resolve_agent_id(name_or_id)
        if not agent_id:
            return
        info = state.pop(agent_id, None)
        if info:
            if info.get("name"):
                name_index.pop(info["name"], None)
            for alias in info.get("aliases", []):
                name_index.pop(alias, None)


def update_agent(name_or_id: str, **kwargs) -> bool:
    """Updates specific fields of an agent's state."""
    with state_lock:
        agent_id = _resolve_agent_id(name_or_id)
        if not agent_id or agent_id not in state:
            return False
        for k, v in kwargs.items():
            state[agent_id][k] = v
        return True


def rename_agent(old_name: str, new_name: str) -> bool:
    """Renames an agent in state without changing its stable agent_id."""
    with state_lock:
        if old_name == new_name:
            return True
        agent_id = name_index.get(old_name)
        if not agent_id or new_name in name_index:
            return False
        name_index[new_name] = agent_id
        state[agent_id]["name"] = new_name
        if "aliases" not in state[agent_id]:
            state[agent_id]["aliases"] = []
        if old_name not in state[agent_id]["aliases"]:
            state[agent_id]["aliases"].append(old_name)
        return True
