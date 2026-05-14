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
    f.write(f"[HOOK] Event: JetskiPreTool, Caller: {caller_name}, Input: {input_data}\n")

# Call the common pre_tool hook
try:
    script_path = os.path.expanduser("~/.gemini/hooks/pre_tool.py")
    process = subprocess.run(
        ["python3", script_path],
        input=json.dumps(input_data).encode(),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    if process.stdout:
        print(f"[JETSKI WRAPPER] Child stdout: {process.stdout.decode()}", file=sys.stderr)
    if process.stderr:
        print(f"[JETSKI WRAPPER] Child stderr: {process.stderr.decode()}", file=sys.stderr)
except Exception as e:
    print(f"[JETSKI WRAPPER] Failed to call child script: {e}", file=sys.stderr)

# Jetski specific logic for approval
try:
    pane_id = os.environ.get("TMUX_PANE")
    if pane_id and input_data:
        agent_id = os.environ.get("AGENT_ID")
        agent_name = None if agent_id else subprocess.check_output(["tmux", "display-message", "-p", "-t", pane_id, "#{@agent_name}"]).decode().strip()
        if agent_id or agent_name:
            tool_call = input_data.get("toolCall", {})
            args = tool_call.get("args", {})
            safe_to_auto_run = args.get("SafeToAutoRun", True)
            with open("/tmp/hooks.log", "a") as f:
                f.write(f"[HOOK] JetskiPreTool: agent_name={agent_name}, safe_to_auto_run={safe_to_auto_run}\n")
            
            # Assume requires approval if SafeToAutoRun is missing or false
            if "SafeToAutoRun" not in args or not args.get("SafeToAutoRun"):
                # Requires approval!
                params = {"waiting_approval": True}
                if agent_id:
                    params["agent_id"] = agent_id
                else:
                    params["agent_name"] = agent_name
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.settimeout(1.0)
                s.connect(os.environ.get("AGENT_TRACKER_SOCKET", os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "agent-tracker", "agent-tracker.sock")))
                s.sendall(json.dumps({"jsonrpc": "2.0", "method": "update_agent", "params": params, "id": 1}).encode())
                s.close()
                subprocess.run(["tmux-status-refresh"], capture_output=True)
except Exception as e:
    with open("/tmp/hooks.log", "a") as f:
        f.write(f"[HOOK] Error in Jetski approval check: {e}\n")

print(json.dumps({"allowTool": True}))
