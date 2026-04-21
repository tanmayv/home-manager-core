import json
import os
import socket
import subprocess
import sys

try:
    input_data = json.load(sys.stdin)
except json.JSONDecodeError:
    input_data = None

parent_pid = os.getppid()

try:
    with open(f"/proc/{os.getppid()}/comm", "r") as f:
        caller_name = f.read().strip()
except Exception:
    caller_name = "unknown"

with open("/tmp/hooks.log", "a") as f:
    f.write(f"[HOOK] Event: AfterAgent, Caller: {caller_name}, Parent PID: {parent_pid}, Input: {input_data}\n")

try:
    pane_id = os.environ.get("TMUX_PANE")
    agent_name = subprocess.check_output(["tmux", "display-message", "-p", "-t", pane_id, "#{@agent_name}"]).decode().strip()
    if agent_name:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(os.path.expanduser("~/.cache/agent-tracker.sock"))
        s.sendall(json.dumps({"jsonrpc": "2.0", "method": "update_agent", "params": {"agent_name": agent_name, "waiting_approval": False, "status": "idle", "running_tool": False}, "id": 1}).encode())
        s.close()
        subprocess.run(["tmux-status-refresh"])
except Exception as e:
    with open("/tmp/hooks.log", "a") as f:
        f.write(f"[HOOK] Error notifying tracker: {e}\n")

print(json.dumps({}))
