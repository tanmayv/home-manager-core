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
        s.settimeout(5.0)
        s.connect(SOCKET_PATH)
        s.sendall(json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode())
        s.shutdown(socket.SHUT_WR)
        resp = s.recv(4096)
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

    send_parser = subparsers.add_parser("send-message", help="Send message to agent")
    send_parser.add_argument("agent_name", help="Target agent name")
    send_parser.add_argument("message", help="Message text")

    focus_parser = subparsers.add_parser("focus", help="Focus agent pane")
    focus_parser.add_argument("agent_name", help="Agent name to focus")

    rename_parser = subparsers.add_parser("rename", help="Rename agent")
    rename_parser.add_argument("old_name", help="Current agent name")
    rename_parser.add_argument("new_name", help="New agent name")

    spin_parser = subparsers.add_parser("spin", help="Spin a new agent")
    spin_parser.add_argument("name", help="Name for the new agent")
    spin_parser.add_argument("command", help="Command to run in the new agent")

    read_inbox_parser = subparsers.add_parser("read-inbox", help="Read agent inbox")
    read_inbox_parser.add_argument("--clear", action="store_true", help="Clear inbox after reading")
    read_inbox_parser.add_argument("--name", help="Agent name to read inbox for (defaults to current agent)")

    args = parser.parse_args()

    if args.subcommand == "list":
        agents = call_rpc("list")
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
        call_rpc("send_message", {"sender_name": "cli-user", "agent_name": args.agent_name, "message": args.message})
        print("Message sent.")

    elif args.subcommand == "focus":
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
    elif args.subcommand == "rename":
        call_rpc("rename", {"old_name": args.old_name, "new_name": args.new_name})
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
        if args.name:
            agent_name = args.name
        else:
            try:
                agent_name = subprocess.check_output(["tmux", "display-message", "-p", "#{@agent_name}"]).decode("utf-8").strip()
            except subprocess.CalledProcessError:
                print("Error: Failed to get agent name from tmux option. Are you in an agent pane?", file=sys.stderr)
                sys.exit(1)
                
            if not agent_name:
                print("Error: @agent_name option is empty. Are you in an agent pane?", file=sys.stderr)
                sys.exit(1)
            
        inbox_content = call_rpc("get_inbox", {"agent_name": agent_name, "clear": args.clear})
        if inbox_content:
            if inbox_content == "Inbox is empty.":
                print(inbox_content)
            else:
                for line in inbox_content.splitlines():
                    if line:
                        try:
                            msg_obj = json.loads(line)
                            print(f"[{msg_obj['timestamp']}] From {msg_obj['sender']}: {msg_obj['message']}")
                        except json.JSONDecodeError:
                            print(f"Raw: {line}")
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
