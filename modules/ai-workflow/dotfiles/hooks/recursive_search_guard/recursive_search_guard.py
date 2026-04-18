#!/usr/bin/env python3
"""Gemini CLI Hook script to guard against recursive searches in google3 root."""

import json
import pathlib
import shlex
import sys


def resolves_to_google3_root(
    path: str | pathlib.Path | None, cwd: pathlib.Path, root: pathlib.Path
) -> bool:
  """Checks if a given path (absolute or relative) matches the google3 root."""
  if not path:
    return cwd.resolve() == root.resolve()
  try:
    # Use cwd / path to handle relative paths correctly.
    abs_path = (cwd / path).resolve()
    return abs_path == root.resolve()
  except (OSError, RuntimeError):
    # If resolution fails (e.g. non-existent path), fallback to absolute path
    # string comparison which is less robust but safer than crashing.
    abs_path = (cwd / path).absolute()
    return str(abs_path) == str(root)


def find_google3_dir(path: pathlib.Path) -> pathlib.Path | None:
  """Returns the path to the google3 directory in <path>.

  This only works if <path> is a child directory of google3, such as in a p4
  client, an unpacked par file or mpm, or a srcfs path.

  Args:
    path: The path to search.

  Returns:
    Path to google3 directory, or None if one could not be found.
  """
  for parent in [path] + list(path.parents):
    if parent.name == "google3":
      return parent
  return None


def is_recursive_grep(
    binary_name: str, args: list[str], cwd: pathlib.Path, root: pathlib.Path
) -> bool:
  """Checks if grep args imply a recursive search on current dir."""
  # rgrep is recursive by default.
  if binary_name == "rgrep":
    is_recursive = True
  else:
    # Check for recursive flags.
    is_recursive = any(
        arg == "--recursive"
        or (
            arg.startswith("-")
            and not arg.startswith("--")
            and ("r" in arg.lower())
        )
        for arg in args
    )

  if not is_recursive:
    return False

  # Filter out known flags to isolate positional arguments.
  non_flags = [arg for arg in args if not arg.startswith("-")]
  if not non_flags:
    # `grep -r` defaults to `.`.
    return resolves_to_google3_root(".", cwd, root)

  # If 1 non-flag, it is the pattern. The search is on `.`
  if len(non_flags) == 1:
    return resolves_to_google3_root(".", cwd, root)

  # If 2+ non-flags, they are the pattern and paths.
  paths = non_flags[1:]
  for p in paths:
    if resolves_to_google3_root(p, cwd, root):
      return True
    if p in ("*", "./*") and cwd.resolve() == root.resolve():
      return True

  return False


def is_recursive_find(
    args: list[str], cwd: pathlib.Path, root: pathlib.Path
) -> bool:
  """Checks if find args imply a search on current dir."""
  # Find syntax: `find [path...] [expression]`
  # The default path is `.`.

  # The first arguments of `find` are paths until an expression or option
  # starting with `-`, `(`, or `!`.

  paths = []
  for arg in args:
    if arg.startswith("-") or arg == "(" or arg == "!":
      break
    paths.append(arg)

  if not paths:
    return resolves_to_google3_root(".", cwd, root)

  for p in paths:
    if resolves_to_google3_root(p, cwd, root):
      return True
    if p in ("*", "./*") and cwd.resolve() == root.resolve():
      return True

  return False


def is_recursive_ls(
    args: list[str], cwd: pathlib.Path, root: pathlib.Path
) -> bool:
  """Checks if ls args imply recursive search on current dir."""
  is_recursive = any(
      arg == "--recursive"
      or (arg.startswith("-") and not arg.startswith("--") and "R" in arg)
      for arg in args
  )
  if not is_recursive:
    return False

  non_flags = [arg for arg in args if not arg.startswith("-")]
  if not non_flags:
    return resolves_to_google3_root(".", cwd, root)

  for p in non_flags:
    if resolves_to_google3_root(p, cwd, root):
      return True
    if p in ("*", "./*") and cwd.resolve() == root.resolve():
      return True

  return False


def main() -> None:
  try:
    raw_input = sys.stdin.read()
    if not raw_input:
      return

    input_data = json.loads(raw_input)
    tool_name = input_data.get("tool_name", "")

    if tool_name != "run_shell_command":
      print(json.dumps({"decision": "allow"}))
      return

    tool_input = input_data.get("tool_input", {})
    command = tool_input.get("command", "")

    cwd_str = input_data["cwd"]
    cwd = pathlib.Path(cwd_str).absolute()

    try:
      args = shlex.split(command)
      if not args:
        print(json.dumps({"decision": "allow"}))
        return
    except Exception:  # pylint: disable=broad-exception-caught
      # If parsing fails, we default to allowing the command to avoid blocking
      # complex valid commands.
      print(json.dumps({"decision": "allow"}))
      return

    binary_path = args[0]
    binary_name = pathlib.Path(binary_path).name

    if binary_name == "timeout" and len(args) > 1:
      # Usage: `timeout DURATION COMMAND`.
      if len(args) > 2 and args[1].replace(".", "", 1).isdigit():
        binary_path = args[2]
        binary_name = pathlib.Path(binary_path).name
        args = args[2:]
      else:
        # Unusual timeout usage.
        pass

    google3_root = find_google3_dir(cwd)
    if not google3_root:
      print(json.dumps({"decision": "allow"}))
      return
    google3_root = google3_root.absolute()

    should_block = False

    if binary_name in ["grep", "egrep", "fgrep", "rgrep"]:
      should_block = is_recursive_grep(binary_name, args[1:], cwd, google3_root)
    elif binary_name == "find":
      should_block = is_recursive_find(args[1:], cwd, google3_root)
    elif binary_name == "ls":
      should_block = is_recursive_ls(args[1:], cwd, google3_root)

    if should_block:
      msg = (
          "This command is blocked in the google3 root because it is a huge"
          " monorepo and recursive searches will hang indefinitely. Please use"
          " the `search_for_files_codesearch` tool, activate the `codesearch`"
          " skill or run this command in a specific subdirectory."
      )
      print(
          json.dumps({
              "decision": "deny",
              "reason": msg,
              "systemMessage": msg,
          })
      )
      return

    print(json.dumps({"decision": "allow"}))

  except Exception as e:  # pylint: disable=broad-exception-caught
    sys.stderr.write(f"Error in recursive_search_guard: {e}\n")
    print(json.dumps({"decision": "allow"}))


if __name__ == "__main__":
  main()
