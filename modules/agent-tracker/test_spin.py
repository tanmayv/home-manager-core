import json
import os
import socket
import subprocess
import sys
import time

SOCKET_PATH = os.path.expanduser("~/.cache/agent-tracker.sock")

def call_rpc(method, params={}):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(SOCKET_PATH)
        s.sendall(json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode())
        resp = s.recv(4096)
        data = json.loads(resp.decode())
        if "error" in data:
            print(f"RPC Error: {data['error']['message']}", file=sys.stderr)
            return None
        return data.get("result")
    except Exception as e:
        print(f"Failed to connect to tracker: {e}", file=sys.stderr)
        return None

def main():
    print("Starting spin_agent test...")

    try:
        session = subprocess.check_output(["tmux", "display-message", "-p", "#S"]).decode("utf-8").strip()
    except Exception as e:
        print(f"Failed to get tmux session: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Current session: {session}")

    # Call spin_agent
    command = "sleep 5"
    print(f"Calling spin_agent with command: {command}...")
    agent_name = call_rpc("spin_agent", {"session": session, "command": command})

    if not agent_name:
        print("Failed to spin agent", file=sys.stderr)
        sys.exit(1)
    print(f"Spun agent: {agent_name}")

    # Wait a bit for the agent to start and register
    print("Waiting for agent to register...")
    time.sleep(2)

    # Verify it is listed
    agents = call_rpc("list")
    if agent_name not in agents:
        print(f"Error: {agent_name} not found in list after spinning", file=sys.stderr)
        sys.exit(1)
    print("Agent found in list!")

    info = agents[agent_name]
    print(f"Agent info: {info}")

    pane = info.get("tmux_pane")
    if pane:
        print(f"Killing test pane {pane}...")
        subprocess.run(["tmux", "kill-pane", "-t", pane])

    print("Test passed successfully!")

if __name__ == "__main__":
    main()
