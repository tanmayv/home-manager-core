#!/usr/bin/env python3
"""Gemini CLI Hook script to normalize google3 paths."""

import json
import os
import sys
from typing import Any, Dict


# List of path arguments that should be normalized if present in tool input.
_NORMALIZABLE_PATH_KEYS = ("file_path", "dir_path")


def normalize_path(path: str) -> str:
  """Normalizes google3 paths to relative paths.

  Args:
    path: The path to normalize.

  Returns:
    The normalized relative path if it matches a google3 pattern, otherwise the
    original path.
  """
  if not path:
    return path

  # Handle Google3 depot paths.
  prefix_depot = "//depot/google3/"
  if path.startswith(prefix_depot):
    return path[len(prefix_depot) :]

  # Handle paths starting with `google3/`.
  prefix_google3 = "google3/"
  if path.startswith(prefix_google3):
    return path[len(prefix_google3) :]

  return path


def process_tool_input(tool_input: Dict[str, Any]) -> Dict[str, Any]:
  """Walks through tool input and normalizes specific path arguments.

  Args:
    tool_input: The dictionary containing tool arguments.

  Returns:
    A copy of the tool input with `file_path` normalized if present.
  """
  modified_input = tool_input.copy()

  for key in _NORMALIZABLE_PATH_KEYS:
    if key in modified_input:
      value = modified_input[key]
      if isinstance(value, str):
        modified_input[key] = normalize_path(value)
      elif isinstance(value, list):
        modified_input[key] = [
            normalize_path(v) if isinstance(v, str) else v for v in value
        ]
  return modified_input


def main():
  """Main entry point for the hook."""
  try:
    raw_input = sys.stdin.read()
    if not raw_input:
      return

    input_data = json.loads(raw_input)
    tool_input = input_data.get("tool_input", {})
    cwd = input_data.get("cwd", "")

    # Normalize CWD to handle trailing slashes.
    cwd = cwd.rstrip("/")

    # Check if we are running in a CitC client context.
    # The google3 directory is typically one level below the CitC root (which
    # contains .citc). So if we are in google3, ../.citc should exist.
    if not os.path.isdir(os.path.join(cwd, "..", ".citc")):
      print(json.dumps({"decision": "allow"}))
      return

    modified_input = process_tool_input(tool_input)

    if modified_input != tool_input:
      print(
          json.dumps({
              "decision": "allow",
              "hookSpecificOutput": {"tool_input": modified_input},
              "systemMessage": (
                  "Automatically normalized Google3 path(s) (stripping"
                  " '//depot/google3/' or 'google3/' prefix) to be relative."
              ),
          })
      )
    else:
      # "allow" lets the tool run with original input.
      print(json.dumps({"decision": "allow"}))

  except Exception:  # pylint: disable=broad-exception-caught
    print(json.dumps({"decision": "allow"}))


if __name__ == "__main__":
  main()
