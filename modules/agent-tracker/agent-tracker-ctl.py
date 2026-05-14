import argparse
import fcntl
import json
import os
import shlex
import socket
import subprocess
import sys
import time

CACHE_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "agent-tracker")
SOCKET_PATH = os.environ.get("AGENT_TRACKER_SOCKET", os.path.join(CACHE_DIR, "agent-tracker.sock"))
LOCK_PATH = os.path.join(CACHE_DIR, "agent-tracker.lock")
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

def main():
    parser = argparse.ArgumentParser(description="Agent Tracker Control")
    subparsers = parser.add_subparsers(dest="subcommand", help="Subcommands")

    subparsers.add_parser("list", help="List agents in JSON format")
    subparsers.add_parser("status-bar", help="List agents for status bar")
    subparsers.add_parser("ensure-running", help="Ensure the tracker daemon is running")
    subparsers.add_parser("daemon", help="Run the tracker daemon in the foreground")

    send_parser = subparsers.add_parser("send-message", help="Send message to agent")
    send_parser.add_argument("agent_name", nargs="?", help="Target agent name")
    send_parser.add_argument("message", help="Message text")
    send_parser.add_argument("--id", dest="agent_id", help="Target agent ID")

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
        if "AGENT_NAME" in os.environ:
            params["agent_name"] = os.environ["AGENT_NAME"]
        agents = call_rpc("list", params)
        print(json.dumps(agents))

    elif args.subcommand == "status-bar":
        agents = call_rpc("list")
        if not agents:
            sys.exit(0)

        try:
            current_pane = subprocess.check_output(["tmux", "display-message", "-p", "#{pane_id}"]).decode("utf-8").strip()
        except subprocess.CalledProcessError:
            current_pane = ""

        formatted = []
        for name, info in agents.items():
            pane = info.get("tmux_pane")
            waiting_approval = info.get("waiting_approval", False)
            status = info.get("status", "")
            
            color = "#414868" # Fallback (Gray)
            if waiting_approval:
                color = "#db4b4b" # Red for Waiting for Approval
            elif pane == current_pane:
                color = "#e0af68" # Yellow for Active Pane
            elif status == "working":
                color = "#7dcfff" # Cyan for Working
            elif status == "idle":
                color = "#9ece6a" # Green for Idle

            range_arg = f"agent:{pane}"
            formatted.append(f"#[range=user|{range_arg}]#[fg={color},bold]{name}#[fg=#414868,nobold]#[norange]")

        print(" · ".join(formatted))

    elif args.subcommand == "send-message":
        if not args.agent_name and not args.agent_id:
            print("Error: send-message requires <agent_name> or --id <agent_id>", file=sys.stderr)
            sys.exit(1)
        params = {"message": args.message}
        if "AGENT_NAME" in os.environ:
            params["sender_name"] = os.environ["AGENT_NAME"]
        if args.agent_id:
            params["agent_id"] = args.agent_id
        else:
            params["agent_name"] = args.agent_name
        call_rpc("send_message", params)
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
        if "AGENT_NAME" in os.environ:
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
        if "AGENT_NAME" in os.environ:
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
