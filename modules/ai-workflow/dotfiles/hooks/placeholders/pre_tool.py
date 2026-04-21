import json
import os
import socket
import subprocess
import sys

try:
    input_data = json.load(sys.stdin)
except json.JSONDecodeError:
    input_data = None

with open("/tmp/hooks.log", "a") as f:
    f.write(f"[HOOK] Event: PreTool, Input: {input_data}\n")

try:
    agent_name = subprocess.check_output(["tmux", "display-message", "-p", "#{@agent_name}"]).decode().strip()
    if agent_name:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(os.path.expanduser("~/.cache/agent-tracker.sock"))
        s.sendall(json.dumps({"jsonrpc": "2.0", "method": "update_agent", "params": {"agent_name": agent_name, "running_tool": True}, "id": 1}).encode())
        s.close()
except Exception as e:
    with open("/tmp/hooks.log", "a") as f:
        f.write(f"[HOOK] Error notifying tracker: {e}\n")

print(json.dumps({}))
