import json
import os
import socket
import subprocess
import sys

try:
    input_data = json.load(sys.stdin)
except json.JSONDecodeError:
    input_data = None

try:
    with open(f"/proc/{os.getppid()}/comm", "r") as f:
        caller_name = f.read().strip()
except Exception:
    caller_name = "unknown"

with open("/tmp/hooks.log", "a") as f:
    f.write(f"[HOOK] Event: PostInvocation, Caller: {caller_name}, Input: {input_data}\n")

try:
    pane_id = os.environ.get("TMUX_PANE")
    if not pane_id:
        with open("/tmp/hooks.log", "a") as f:
            f.write("[HOOK] No TMUX_PANE found in environment. Skipping tracker update.\n")
    else:
        agent_name = subprocess.check_output(["tmux", "display-message", "-p", "-t", pane_id, "#{@agent_name}"]).decode().strip()
        if agent_name:
            import time
            for _ in range(3):
                try:
                    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                    s.settimeout(1.0)
                    s.connect(os.path.expanduser("~/.cache/agent-tracker.sock"))
                    s.sendall(json.dumps({"jsonrpc": "2.0", "method": "update_agent", "params": {"agent_name": agent_name, "waiting_approval": False, "status": "waiting"}, "id": 1}).encode())
                    s.close()
                    subprocess.run(["tmux-status-refresh"], capture_output=True)
                    break
                except Exception as e:
                    with open("/tmp/hooks.log", "a") as f:
                        f.write(f"[HOOK] Retry failed: {e}\n")
                    time.sleep(0.1)
except Exception as e:
    with open("/tmp/hooks.log", "a") as f:
        f.write(f"[HOOK] Error notifying tracker: {e}\n")

print(json.dumps({}))
