import argparse
import fcntl
import json
import os
import shlex
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid

CACHE_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "agent-tracker")
SOCKET_PATH = os.environ.get("AGENT_TRACKER_SOCKET", os.path.join(CACHE_DIR, "agent-tracker.sock"))
LOCK_PATH = os.path.join(CACHE_DIR, "agent-tracker.lock")
REGISTRY_STATUS_PATH = os.path.join(CACHE_DIR, "registry-status.json")
DEFAULT_STARTUP_TIMEOUT = 5.0


def _can_connect() -> bool:
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(0.5)
        s.connect(SOCKET_PATH)
        s.close()
        return True
    except OSError:
        return False


def ensure_tracker_running(timeout: float = DEFAULT_STARTUP_TIMEOUT) -> bool:
    os.makedirs(CACHE_DIR, exist_ok=True)
    if _can_connect():
        return True

    daemon_cmd = os.environ.get("AGENT_TRACKER_DAEMON")
    if not daemon_cmd:
        return False

    with open(LOCK_PATH, "a+") as lock_file:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX)

        if _can_connect():
            return True

        if os.path.exists(SOCKET_PATH) and not _can_connect():
            try:
                os.remove(SOCKET_PATH)
            except FileNotFoundError:
                pass

        if not _can_connect():
            subprocess.Popen(
                shlex.split(daemon_cmd),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                stdin=subprocess.DEVNULL,
                start_new_session=True,
            )

    deadline = time.time() + timeout
    while time.time() < deadline:
        if _can_connect():
            return True
        time.sleep(0.1)

    return _can_connect()


def call_rpc(method, params={}):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(5.0)
        s.connect(SOCKET_PATH)
        s.sendall(json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode())
        s.shutdown(socket.SHUT_WR)

        chunks = []
        while True:
            chunk = s.recv(4096)
            if not chunk:
                break
            chunks.append(chunk)
        resp = b"".join(chunks)

        data = json.loads(resp.decode())
        if "error" in data:
            print(f"Error: {data['error']['message']}", file=sys.stderr)
            sys.exit(1)
        return data.get("result")
    except (socket.error, socket.timeout) as e:
        print(f"Socket communication failed: {e}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Failed to decode response from tracker: {e}", file=sys.stderr)
        sys.exit(1)


def get_current_tmux_pane(fallback: str | None = None) -> str:
    if fallback is not None:
        return fallback
    try:
        return subprocess.check_output(["tmux", "display-message", "-p", "#{pane_id}"]).decode("utf-8").strip()
    except subprocess.CalledProcessError:
        return ""


def is_uuid(value: str | None) -> bool:
    try:
        uuid.UUID(value or "")
        return True
    except (ValueError, TypeError, AttributeError):
        return False


def _read_token_config(config: dict) -> str:
    if config.get("token"):
        return str(config.get("token"))
    token_file = config.get("token-file") or config.get("tokenFile")
    if token_file:
        try:
            with open(token_file, "r") as f:
                return f.read().strip()
        except Exception:
            return ""
    return ""


def registry_configs() -> list[dict]:
    raw = os.environ.get("AGENT_REGISTRIES_JSON", "").strip()
    if raw:
        try:
            configs = json.loads(raw)
        except json.JSONDecodeError:
            return []
        if isinstance(configs, dict):
            configs = configs.get("registries") or []
        return [{**c, "token": _read_token_config(c)} for c in configs if isinstance(c, dict) and c.get("url")]
    registry_url = os.environ.get("AGENT_REGISTRY_URL", "").strip()
    if not registry_url:
        return []
    return [{"name": "default", "url": registry_url, "token": os.environ.get("AGENT_REGISTRY_TOKEN", "")}]


def fetch_registry_agents(timeout: float = 3.0) -> dict:
    """Best-effort fetch of remote agents from all configured registries."""
    remote_agents = {}
    for config in registry_configs():
        registry_url = str(config.get("url", "")).strip().rstrip("/")
        if not registry_url:
            continue
        token = str(config.get("token") or "")
        req = urllib.request.Request(
            f"{registry_url}/agents",
            headers={**({"Authorization": f"Bearer {token}"} if token else {})},
            method="GET",
        )
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                if resp.status != 200:
                    continue
                payload = json.loads(resp.read().decode() or "{}")
        except (OSError, urllib.error.URLError, json.JSONDecodeError):
            continue
        registry_name = config.get("name") or "default"
        for agent in payload.get("agents") or []:
            hostname = agent.get("hostname")
            name = agent.get("name")
            if not hostname or not name:
                continue
            base_key = f"{hostname}/{name}"
            key = base_key
            if base_key in remote_agents and remote_agents[base_key].get("agent_id") != agent.get("agent_id"):
                existing = remote_agents.pop(base_key)
                existing_registry = existing.get("registry_name") or "default"
                existing_key = f"{existing_registry}:{base_key}"
                remote_agents[existing_key] = {**existing, "name": existing_key, "target_address": existing_key}
                key = f"{registry_name}:{base_key}"
            elif base_key not in remote_agents and any(k.endswith(f":{base_key}") for k in remote_agents):
                key = f"{registry_name}:{base_key}"
            remote_agents[key] = {**agent, "name": key, "scope": "remote", "target_address": key, "registry_name": registry_name}
    return remote_agents


def merge_registry_agents(local_agents: dict, remote_agents: dict) -> dict:
    merged = {name: {**info, "scope": info.get("scope", "local")} for name, info in (local_agents or {}).items()}
    local_agent_ids = {info.get("agent_id") for info in (local_agents or {}).values() if info.get("agent_id")}
    for name, info in (remote_agents or {}).items():
        if info.get("agent_id") in local_agent_ids:
            continue
        merged[name] = info
    return merged


def load_registry_status() -> dict:
    try:
        with open(REGISTRY_STATUS_PATH, "r") as f:
            return json.load(f)
    except Exception:
        return {}


def _is_entry_fresh(entry: dict, now: float, max_age: int) -> bool:
    last_success = entry.get("last_success")
    return bool(entry.get("connected") and isinstance(last_success, (int, float)) and now - last_success <= max_age)


def registry_connection_states(status: dict | None = None, now: float | None = None) -> list[tuple[str, bool]]:
    configs = registry_configs()
    if not configs:
        return []
    status = load_registry_status() if status is None else status
    now = time.time() if now is None else now
    heartbeat_interval = int(os.environ.get("AGENT_REGISTRY_HEARTBEAT_SECONDS", "30"))
    max_age = max(heartbeat_interval * 2 + 5, 15)
    entries = status.get("registries") or {}
    states = []
    for config in configs:
        name = config.get("name") or "default"
        entry = entries.get(name)
        if entry is None and name == "default":
            entry = status
        states.append((name, _is_entry_fresh(entry or {}, now, max_age)))
    return states


def is_registry_connected(now: float | None = None) -> bool:
    return any(connected for _, connected in registry_connection_states(now=now))


def format_registry_status(status: dict, now: float | None = None) -> str:
    now = time.time() if now is None else now
    registries = status.get("registries") or {"default": status} if status else {}
    if not registries:
        return "No registry status found."
    lines = []
    for name in sorted(registries):
        entry = registries[name]
        ok = "connected" if entry.get("connected") else "disconnected"
        last_success = entry.get("last_success")
        age = "never" if not isinstance(last_success, (int, float)) else f"{int(now - last_success)}s ago"
        detail = entry.get("last_error") or f"status={entry.get('status_code')}"
        lines.append(f"{name}: {ok}, last_success={age}, url={entry.get('registry_url')}, {detail}")
    return "\n".join(lines)


def format_registry_dots(states: list[tuple[str, bool]] | None, connected_fallback: bool, color_ok: str, color_bad: str) -> str:
    if not states:
        color = color_ok if connected_fallback else color_bad
        dots = f"#[fg={color},bold]●"
    else:
        dots = "".join(f"#[fg={color_ok if connected else color_bad},bold]●" for _, connected in states)
    return f"#[range=user|agent-registries]{dots}#[norange] "


def format_status_bar(agents: dict, current_pane: str, registry_connected: bool = False, registry_states: list[tuple[str, bool]] | None = None) -> str:
    if not agents:
        return ""

    color8 = os.environ.get("PALETTE_COLOR8", "#414868")
    color1 = os.environ.get("PALETTE_COLOR1", "#db4b4b")
    color3 = os.environ.get("PALETTE_COLOR3", "#e0af68")
    color6 = os.environ.get("PALETTE_COLOR6", "#7dcfff")
    color2 = os.environ.get("PALETTE_COLOR2", "#9ece6a")
    color4 = os.environ.get("PALETTE_COLOR4", "#2ac3de")

    formatted = []
    for name, info in agents.items():
        pane = info.get("tmux_pane")
        waiting_approval = info.get("waiting_approval", False)
        status = info.get("status", "")

        color = color8
        if waiting_approval:
            color = color1
        elif pane == current_pane:
            color = color3
        elif status == "working":
            color = color6
        elif status == "idle":
            color = color2

        range_arg = f"agent:{pane}"
        formatted.append(f"#[range=user|{range_arg}]#[fg={color},bold]{name}#[fg={color8},nobold]#[norange]")

    if not formatted:
        return ""

    indicator = format_registry_dots(registry_states, registry_connected, color2, color1).rstrip()
    prefix = f"#[fg={color4},bold]Active Agents: #[fg={color8},nobold]"
    return f"{prefix}{' · '.join(formatted)}#[align=right]{indicator}#[default]"

def main():
    parser = argparse.ArgumentParser(
        description="Agent Tracker Control",
        epilog=(
            "Remote messaging via agent-registry:\n"
            "  send-message alice \"hello\"                 # local-only by bare name\n"
            "  send-message 123e4567-e89b-12d3-a456-426614174000 \"hello\"  # local-only by bare UUID\n"
            "  send-message host-a/alice \"hello\"          # remote by hostname/name\n"
            "  send-message host-a/123e4567-e89b-12d3-a456-426614174000 \"hello\"  # remote by hostname/UUID\n"
            "\n"
            "Bare names/UUIDs stay local-only. Host-qualified targets require registry integration."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    subparsers = parser.add_subparsers(dest="subcommand", help="Subcommands")

    subparsers.add_parser("list", help="List agents in JSON format")
    status_bar_parser = subparsers.add_parser("status-bar", help="List agents for status bar")
    status_bar_parser.add_argument("current_pane", nargs="?", help="Current tmux pane ID")
    subparsers.add_parser("registry-status", help="Show per-registry connection status")
    subparsers.add_parser("ensure-running", help="Ensure the tracker daemon is running")
    subparsers.add_parser("daemon", help="Run the tracker daemon in the foreground")

    send_parser = subparsers.add_parser(
        "send-message",
        help="Send message to a local agent or a remote host-qualified target",
        description=(
            "Send a message to a local or remote agent.\n"
            "Examples:\n"
            "  agent-tracker-ctl send-message alice \"hello\"\n"
            "  agent-tracker-ctl send-message host-a/alice \"hello\"\n"
            "  agent-tracker-ctl send-message host-a/123e4567-e89b-12d3-a456-426614174000 \"hello\"\n"
            "\n"
            "Bare names/UUIDs are always local-only. Use HOST/TARGET for remote delivery via agent-registry."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    send_parser.add_argument("target", nargs="?", metavar="TARGET", help="Local agent name/UUID or remote HOST/NAME_OR_UUID")
    send_parser.add_argument("message", help="Message text")
    send_parser.add_argument("--id", dest="agent_id", help="Target local agent ID (legacy local-only form)")

    focus_parser = subparsers.add_parser("focus", help="Focus agent pane")
    focus_group = focus_parser.add_mutually_exclusive_group(required=True)
    focus_group.add_argument("agent_name", nargs="?", help="Agent name to focus")
    focus_group.add_argument("--id", dest="agent_id", help="Agent ID to focus")
    focus_group.add_argument("--next", action="store_true", help="Focus next agent")
    focus_group.add_argument("--prev", action="store_true", help="Focus previous agent")

    rename_parser = subparsers.add_parser("rename", help="Rename agent")
    rename_parser.add_argument("names", nargs="+", help="New name (or old_name new_name with --force)")
    rename_parser.add_argument("--force", action="store_true", help="Force rename of another agent")

    spin_parser = subparsers.add_parser("spin", help="Spin a new agent")
    spin_parser.add_argument("name", help="Name for the new agent")
    spin_parser.add_argument("command", choices=["jetski", "gemini"], help="Command to run in the new agent")

    read_inbox_parser = subparsers.add_parser("read-inbox", help="Read agent inbox")
    read_inbox_parser.add_argument("--clear", action="store_true", help="Clear inbox after reading")
    read_inbox_parser.add_argument("--name", help="Agent name to read inbox for (defaults to current agent)")
    read_inbox_parser.add_argument("--id", dest="agent_id", help="Agent ID to read inbox for")
    read_inbox_parser.add_argument("--last", "-l", type=int, help="Read last N messages")

    subparsers.add_parser("whoami", help="Show current agent identity")

    unregister_parser = subparsers.add_parser("unregister", help="Unregister agent")
    group = unregister_parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--name", help="Agent name to unregister")
    group.add_argument("--id", dest="agent_id", help="Agent ID to unregister")
    group.add_argument("--pane", help="Tmux pane ID to unregister")

    args = parser.parse_args()

    if args.subcommand == "daemon":
        daemon_cmd = os.environ.get("AGENT_TRACKER_DAEMON")
        if not daemon_cmd:
            print("Error: AGENT_TRACKER_DAEMON is not configured.", file=sys.stderr)
            sys.exit(1)
        os.execvp(shlex.split(daemon_cmd)[0], shlex.split(daemon_cmd))

    if args.subcommand == "ensure-running":
        if ensure_tracker_running():
            sys.exit(0)
        print("Error: failed to start or connect to agent-tracker.", file=sys.stderr)
        sys.exit(1)

    if args.subcommand and not ensure_tracker_running():
        print("Error: failed to start or connect to agent-tracker.", file=sys.stderr)
        sys.exit(1)

    if args.subcommand == "list":
        params = {}
        if "AGENT_ID" in os.environ:
            params["agent_id"] = os.environ["AGENT_ID"]
        elif "AGENT_NAME" in os.environ:
            params["agent_name"] = os.environ["AGENT_NAME"]
        agents = call_rpc("list", params)
        agents = merge_registry_agents(agents, fetch_registry_agents())
        print(json.dumps(agents))

    elif args.subcommand == "status-bar":
        agents = call_rpc("list")
        current_pane = get_current_tmux_pane(args.current_pane)
        status_bar = format_status_bar(agents, current_pane, registry_connected=is_registry_connected(), registry_states=registry_connection_states())
        if status_bar:
            print(status_bar, end="")

    elif args.subcommand == "registry-status":
        print(format_registry_status(load_registry_status()))

    elif args.subcommand == "send-message":
        if not args.target and not args.agent_id:
            print("Error: send-message requires <target> or --id <agent_id>", file=sys.stderr)
            sys.exit(1)
        params = {"message": args.message}
        if "AGENT_ID" in os.environ:
            params["sender_id"] = os.environ["AGENT_ID"]
        elif "AGENT_NAME" in os.environ:
            params["sender_name"] = os.environ["AGENT_NAME"]
        if args.agent_id:
            params["agent_id"] = args.agent_id
        elif "/" in args.target:
            params["target_address"] = args.target
        elif is_uuid(args.target):
            params["agent_id"] = args.target
        else:
            params["agent_name"] = args.target
        res = call_rpc("send_message", params)
        if isinstance(res, dict) and res.get("warning"):
            print(res["warning"], file=sys.stderr)
        print("Message sent.")

    elif args.subcommand == "focus":
        agents = call_rpc("list")
        if not agents:
            print("No active agents.", file=sys.stderr)
            sys.exit(1)

        agent_names = list(agents.keys())

        if args.next or args.prev:
            try:
                current_pane = subprocess.check_output(["tmux", "display-message", "-p", "#{pane_id}"]).decode("utf-8").strip()
            except subprocess.CalledProcessError:
                current_pane = ""

            current_agent = None
            for name, info in agents.items():
                if info.get("tmux_pane") == current_pane:
                    current_agent = name
                    break

            if not current_agent:
                # Fallback: just pick the first one if we can't find current
                target_agent = agent_names[0]
            else:
                current_index = agent_names.index(current_agent)
                if args.next:
                    target_index = (current_index + 1) % len(agent_names)
                else:
                    target_index = (current_index - 1) % len(agent_names)
                target_agent = agent_names[target_index]
        else:
            target_agent = args.agent_name
            if args.agent_id and not target_agent:
                target_agent = next((name for name, info in agents.items() if info.get("agent_id") == args.agent_id or info.get("uuid") == args.agent_id), None)

        if target_agent in agents:
            info = agents[target_agent]
            session = info.get("session")
            pane = info.get("tmux_pane")
            socket_path = info.get("tmux_socket")

            tmux_cmd = ["tmux"]
            if socket_path:
                tmux_cmd.extend(["-S", socket_path])

            subprocess.run(tmux_cmd + ["switch-client", "-t", session])
            subprocess.run(tmux_cmd + ["select-window", "-t", pane])
            subprocess.run(tmux_cmd + ["select-pane", "-t", pane])
        else:
            print(f"Agent {target_agent} not found.", file=sys.stderr)
            sys.exit(1)
    elif args.subcommand == "rename":
        force = args.force
        if force:
            if len(args.names) != 2:
                print("Error: --force requires <old_name> <new_name>", file=sys.stderr)
                sys.exit(1)
            old_name, new_name = args.names
        else:
            if len(args.names) != 1:
                print("Error: rename requires <new_name> (use --force to rename someone else)", file=sys.stderr)
                sys.exit(1)
            old_name = None
            new_name = args.names[0]
            
        params = {"old_name": old_name, "new_name": new_name, "force": force}
        if "AGENT_ID" in os.environ:
            params["agent_id"] = os.environ["AGENT_ID"]
        elif "AGENT_NAME" in os.environ:
            params["agent_name"] = os.environ["AGENT_NAME"]
        call_rpc("rename", params)
        print("Agent renamed.")
    elif args.subcommand == "spin":
        try:
            session = subprocess.check_output(["tmux", "display-message", "-p", "#S"]).decode("utf-8").strip()
        except subprocess.CalledProcessError:
            print("Error: Failed to get current tmux session. Are you in a tmux session?", file=sys.stderr)
            sys.exit(1)
            
        resolved_name = call_rpc("spin_agent", {"session": session, "command": args.command, "name": args.name})
        if resolved_name:
            print(f"Agent spun successfully as: {resolved_name}")
    elif args.subcommand == "read-inbox":
        agent_name = args.name
        params = {"clear": args.clear}
        
        if args.agent_id:
            params["agent_id"] = args.agent_id
        elif agent_name:
            params["agent_name"] = agent_name
        elif "AGENT_ID" in os.environ:
            params["agent_id"] = os.environ["AGENT_ID"]
        elif "AGENT_NAME" in os.environ:
            params["agent_name"] = os.environ["AGENT_NAME"]
            
        if args.last is not None:
            params["last_n"] = args.last
            
        inbox_data = call_rpc("get_inbox", params)
        
        if inbox_data:
            mode = inbox_data.get("mode")
            messages = inbox_data.get("messages", [])
            
            if mode == "history" and not args.last:
                if not messages:
                    print("No unread messages.")
                else:
                    for msg in messages:
                        read_str = "Read" if msg.get("read", False) else "Unread"
                        msg_text = msg.get('message', '')
                        truncated = msg_text[:50] + "..." if len(msg_text) > 50 else msg_text
                        print(f"{msg.get('timestamp')}, {read_str}, {msg.get('sender')}, {truncated}")
                    print("use agent-tracker-ctl read-inbox --last n to print last n messages.")
            else:
                if not messages:
                    if mode == "last_n":
                        print("No messages found.")
                    else:
                        print("No unread messages.")
                else:
                    for msg in messages:
                        print(f"[{msg.get('timestamp')}] From {msg.get('sender')}: {msg.get('message')}")
        else:
            print("No messages found.")

    elif args.subcommand == "whoami":
        params = {}
        if "AGENT_ID" in os.environ:
            params["agent_id"] = os.environ["AGENT_ID"]
        elif "AGENT_NAME" in os.environ:
            params["agent_name"] = os.environ["AGENT_NAME"]
        info = call_rpc("whoami", params)
        if info:
            print(f"Name:     {info.get('name')}")
            print(f"Agent ID: {info.get('agent_id') or info.get('uuid')}")
            print(f"UUID:     {info.get('uuid')}")
            print(f"PID:      {info.get('pid')}")
            print(f"Pane ID:  {info.get('pane_id')}")

    elif args.subcommand == "unregister":
        params = {}
        if args.name:
            params["agent_name"] = args.name
        if args.agent_id:
            params["agent_id"] = args.agent_id
        if args.pane:
            params["tmux_pane"] = args.pane
        call_rpc("unregister", params)
        print("Agent unregistered.")

    else:
        parser.print_help()

if __name__ == "__main__":
    main()
