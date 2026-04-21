import argparse
import json
import os
import socket
import subprocess
import sys

SOCKET_PATH = os.path.expanduser("~/.cache/agent-tracker.sock")

def call_rpc(method, params={}):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(SOCKET_PATH)
        s.sendall(json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode())
        resp = s.recv(4096)
        data = json.loads(resp.decode())
        if "error" in data:
            print(f"Error: {data['error']['message']}", file=sys.stderr)
            sys.exit(1)
        return data.get("result")
    except Exception as e:
        print(f"Failed to connect to tracker: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Agent Tracker Control")
    subparsers = parser.add_subparsers(dest="command", help="Subcommands")

    subparsers.add_parser("list", help="List agents in JSON format")
    subparsers.add_parser("status-bar", help="List agents for status bar")

    send_parser = subparsers.add_parser("send-message", help="Send message to agent")
    send_parser.add_argument("agent_name", help="Target agent name")
    send_parser.add_argument("message", help="Message text")

    focus_parser = subparsers.add_parser("focus", help="Focus agent pane")
    focus_parser.add_argument("agent_name", help="Agent name to focus")

    args = parser.parse_args()

    if args.command == "list":
        agents = call_rpc("list")
        print(json.dumps(agents))

    elif args.command == "status-bar":
        agents = call_rpc("list")
        if not agents:
            sys.exit(0)

        try:
            current_pane = subprocess.check_output(["tmux", "display-message", "-p", "#{pane_id}"]).decode("utf-8").strip()
        except:
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

    elif args.command == "send-message":
        call_rpc("send_message", {"sender_name": "cli-user", "agent_name": args.agent_name, "message": args.message})
        print("Message sent.")

    elif args.command == "focus":
        agents = call_rpc("list")
        if args.agent_name in agents:
            info = agents[args.agent_name]
            session = info.get("session")
            pane = info.get("tmux_pane")
            socket_path = info.get("tmux_socket")

            tmux_cmd = ["tmux"]
            if socket_path:
                tmux_cmd.extend(["-S", socket_path])

            subprocess.run(tmux_cmd + ["switch-client", "-t", session])
            subprocess.run(tmux_cmd + ["select-pane", "-t", pane])
        else:
            print(f"Agent {args.agent_name} not found.", file=sys.stderr)
            sys.exit(1)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
