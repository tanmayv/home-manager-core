import json
import os
import socket
import subprocess
import sys
import time

SOCKET_PATH = os.environ.get("AGENT_TRACKER_SOCKET", os.path.expanduser("~/.cache/agent-tracker.sock"))

def call_rpc(method, params={}):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(SOCKET_PATH)
        s.sendall(json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode())
        s.shutdown(socket.SHUT_WR)
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
    print("Starting rename test...")

    # 1. Register a dummy agent
    dummy_name = "test-dummy-agent"
    pid = os.getpid()

    params = {
        "session": "test-session",
        "tmux_pane": "%999",
        "wrapper_pid": pid,
        "tmux_socket": "dummy_socket"
    }

    print("Registering dummy agent...")
    assigned_name = call_rpc("register", params)
    if not assigned_name:
        print("Failed to register agent", file=sys.stderr)
        sys.exit(1)
    print(f"Registered as {assigned_name}")

    # 2. Verify it is listed
    agents = call_rpc("list")
    if assigned_name not in agents:
        print(f"Error: {assigned_name} not found in list after registration", file=sys.stderr)
        sys.exit(1)

    # 3. Rename it
    new_name = f"{assigned_name}-renamed"
    print(f"Renaming {assigned_name} to {new_name}...")

    # Call agent-tracker-ctl.py directly to test the changes without needing to build/install
    ctl_script = "/usr/local/google/home/tanmayvijay/minimal-cloudtop/modules/agent-tracker/agent-tracker-ctl.py"
    try:
        subprocess.run(["python3", ctl_script, "rename", assigned_name, new_name], check=True, capture_output=True)
    except subprocess.CalledProcessError as e:
        print(f"Error calling agent-tracker-ctl rename: {e.stderr.decode()}", file=sys.stderr)
        sys.exit(1)

    # 4. Verify name change took effect
    agents = call_rpc("list")
    if new_name not in agents:
        print(f"Error: {new_name} not found in list after rename", file=sys.stderr)
        sys.exit(1)
    if assigned_name in agents:
        print(f"Error: Old name {assigned_name} still exists in list after rename", file=sys.stderr)
        sys.exit(1)

    print("Test passed successfully!")

if __name__ == "__main__":
    main()
