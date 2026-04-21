import json
import sys

try:
    input_data = json.load(sys.stdin)
except json.JSONDecodeError:
    input_data = None

with open("/tmp/hooks.log", "a") as f:
    f.write(f"[HOOK] Event: PostTool, Input: {input_data}\n")

print(json.dumps({}))
