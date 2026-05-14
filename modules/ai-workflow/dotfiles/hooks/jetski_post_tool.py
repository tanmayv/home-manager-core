import json
import os
import subprocess
import sys

try:
    input_data = json.load(sys.stdin)
except json.JSONDecodeError:
    input_data = None

try:
    script_path = os.path.expanduser("~/.gemini/hooks/post_tool.py")
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

caller_name = os.environ.get("AGENT_NAME") or os.environ.get("AGENT_ID") or os.path.basename(sys.argv[0]) or "unknown"

with open("/tmp/hooks.log", "a") as f:
    f.write(f"[HOOK] Event: JetskiPostTool, Caller: {caller_name}, Input: {input_data}\n")

print(json.dumps({}))
