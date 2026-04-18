#!/usr/bin/env python3
"""Hook script to get Google3 context information."""

import getpass
import json
import os
import subprocess
import sys


def get_citc_info(cwd) -> str:
  """Runs citctools info and returns the output."""
  try:
    return subprocess.check_output(
        ["citctools", "info"], cwd=cwd, stderr=subprocess.DEVNULL, text=True
    )
  except (subprocess.CalledProcessError, FileNotFoundError):
    return ""


def get_vcs_type() -> str:
  """Determines the VCS type using vcstool."""
  try:
    vcs_type_raw = subprocess.check_output(
        ["/google/bin/releases/piper-fig/vcstool/vcstool", "debug-vcs-string"],
        stderr=subprocess.DEVNULL,
        text=True,
    )
    if "piper" in vcs_type_raw.lower():
      return "piper"
    elif "fig" in vcs_type_raw.lower():
      return "fig"
    elif "jj" in vcs_type_raw.lower():
      return "jj"
    else:
      return "unknown"
  except (subprocess.CalledProcessError, FileNotFoundError):
    return "unknown"


def main():
  try:
    raw_input = sys.stdin.read()
    input_data = json.loads(raw_input) if raw_input else {}
  except json.JSONDecodeError:
    input_data = {}
  cwd = input_data.get("cwd") or os.environ.get("GEMINI_PROJECT_DIR")

  g3_dir = ""
  ws_root = ""
  if cwd and os.path.isdir(cwd):
    citc_info = get_citc_info(cwd)
    if citc_info:
      for line in citc_info.splitlines():
        if line.startswith("Root directory:"):
          ws_root = line.replace("Root directory:", "").strip()
          g3_dir = os.path.join(ws_root, "google3")
          break

  if not g3_dir or not os.path.isdir(g3_dir):
    context = "  is_google3: false"
  else:
    ws_name = os.path.basename(ws_root)
    vcs_type = get_vcs_type()
    user_id = getpass.getuser()

    context = (
        f"  is_google3: true\n"
        f'  workspace_name: "{ws_name}"\n'
        f'  vcs_type: "{vcs_type}"\n'
        f'  user: "{user_id}"\n'
    )

  output = {"hookSpecificOutput": {"additionalContext": context}}
  print(json.dumps(output, indent=2))


if __name__ == "__main__":
  main()
