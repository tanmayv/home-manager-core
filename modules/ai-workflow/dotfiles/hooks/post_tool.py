import json
import os
import socket
import subprocess
import sys

def log_event(message):
    try:
        with open("/tmp/hooks.log", "a") as f:
            f.write(message + "\n")
    except Exception as e:
        sys.stderr.write(f"[HOOK] Failed to write to log file: {e}\n")
        sys.stderr.write(message + "\n")

try:
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        input_data = None
    except Exception as e:
        log_event(f"[HOOK] Error reading stdin: {e}")
        input_data = None

    try:
        with open(f"/proc/{os.getppid()}/comm", "r") as f:
            caller_name = f.read().strip()
    except Exception:
        caller_name = "unknown"

    log_event(f"[HOOK] Event: PostTool, Caller: {caller_name}, Input: {input_data}")

    try:
        pane_id = os.environ.get("TMUX_PANE")
        if not pane_id:
            log_event("[HOOK] No TMUX_PANE found in environment. Skipping tracker update.")
        else:
            agent_id = os.environ.get("AGENT_ID")
            agent_name = None if agent_id else subprocess.check_output(["tmux", "display-message", "-p", "-t", pane_id, "#{@agent_name}"]).decode().strip()
            if agent_id or agent_name:
                params = {"waiting_approval": False, "status": "waiting"}
                if agent_id:
                    params["agent_id"] = agent_id
                else:
                    params["agent_name"] = agent_name
                import time
                for _ in range(3):
                    try:
                        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                        s.settimeout(1.0)
                        s.connect(os.environ.get("AGENT_TRACKER_SOCKET", os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "agent-tracker", "agent-tracker.sock")))
                        s.sendall(json.dumps({"jsonrpc": "2.0", "method": "update_agent", "params": params, "id": 1}).encode())
                        s.close()
                        subprocess.run(["tmux-status-refresh"], capture_output=True)
                        break
                    except Exception as e:
                        log_event(f"[HOOK] Retry failed: {e}")
                        time.sleep(0.1)
    except Exception as e:
        log_event(f"[HOOK] Error notifying tracker: {e}")

except Exception as e:
    log_event(f"[HOOK] Uncaught exception in hook script: {e}")

# Always print empty JSON as expected by framework
print(json.dumps({}))
