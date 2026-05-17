import argparse
import os
import shlex
import shutil
import subprocess
import sys


def ensure_env(home: str, tracker_socket: str | None = None) -> None:
    os.environ.setdefault("HOME", home)
    os.environ.setdefault("USER", os.path.basename(home))
    os.environ.setdefault("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    path_parts = [
        os.path.join(home, ".nix-profile", "bin"),
        f"/etc/profiles/per-user/{os.environ.get('USER', '')}/bin",
        "/nix/var/nix/profiles/default/bin",
        "/run/current-system/sw/bin",
        os.environ.get("PATH", ""),
    ]
    os.environ["PATH"] = ":".join(part for part in path_parts if part)
    if tracker_socket:
        os.environ.setdefault("AGENT_TRACKER_SOCKET", tracker_socket)


def tmux_cmd(args: list[str], check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["tmux", *args],
        text=True,
        capture_output=True,
        check=check,
        env=os.environ,
    )


def session_exists(session: str) -> bool:
    return tmux_cmd(["has-session", "-t", session], check=False).returncode == 0


def ensure_session(session: str, cwd: str) -> bool:
    if session_exists(session):
        return False
    tmux_cmd(["new-session", "-d", "-s", session, "-c", cwd])
    return True


def list_panes(session: str) -> list[dict]:
    out = tmux_cmd([
        "list-panes",
        "-t",
        session,
        "-F",
        "#{pane_id}\t#{pane_dead}\t#{pane_current_command}\t#{@agent_name}",
    ]).stdout.strip()
    if not out:
        return []
    panes = []
    for line in out.splitlines():
        pane_id, pane_dead, pane_cmd, agent_name = (line.split("\t") + ["", "", "", ""])[:4]
        panes.append({
            "pane_id": pane_id,
            "pane_dead": pane_dead == "1",
            "pane_current_command": pane_cmd,
            "agent_name": agent_name,
        })
    return panes


def build_launch_command(agent_name: str, command: str, tracker_socket: str | None = None) -> str:
    command_parts = shlex.split(command)
    if not command_parts:
        raise ValueError("command must not be empty")
    env_parts = ["env", f"SUGGESTED_AGENT_NAME={agent_name}"]
    if tracker_socket:
        env_parts.append(f"AGENT_TRACKER_SOCKET={tracker_socket}")
    return shlex.join(env_parts + ["agent-wrapper", *command_parts])


def ensure_requirements(command: str) -> None:
    missing = []
    if shutil.which("tmux") is None:
        missing.append("tmux")
    if shutil.which("agent-wrapper") is None:
        missing.append("agent-wrapper")
    command_parts = shlex.split(command)
    if not command_parts:
        missing.append("command")
    elif shutil.which(command_parts[0]) is None and not os.path.exists(command_parts[0]):
        missing.append(command_parts[0])
    if missing:
        raise RuntimeError(f"missing required executables: {', '.join(missing)}")


def reconcile_agent(agent_name: str, session: str, cwd: str, command: str, tracker_socket: str | None = None) -> str:
    ensure_requirements(command)
    session_created = ensure_session(session, cwd)
    launch_cmd = build_launch_command(agent_name, command, tracker_socket)
    for pane in list_panes(session):
        if pane["agent_name"] != agent_name:
            continue
        if not pane["pane_dead"]:
            return "session-created-already-running" if session_created else "already-running"
        tmux_cmd(["respawn-pane", "-k", "-t", pane["pane_id"], "-c", cwd, launch_cmd])
        return "session-created-respawned" if session_created else "respawned"
    tmux_cmd(["new-window", "-d", "-t", session, "-n", agent_name, "-c", cwd, launch_cmd])
    return "session-created-started" if session_created else "started"


def main() -> int:
    parser = argparse.ArgumentParser(description="Reconcile a registry-managed agent inside tmux")
    parser.add_argument("--agent-name", required=True)
    parser.add_argument("--session", required=True)
    parser.add_argument("--cwd", required=True)
    parser.add_argument("--command", required=True)
    parser.add_argument("--home", required=True)
    parser.add_argument("--tracker-socket")
    args = parser.parse_args()

    home = os.path.expanduser(args.home)
    cwd = os.path.expanduser(args.cwd)
    if cwd == "~":
        cwd = home
    ensure_env(home, args.tracker_socket)

    try:
        result = reconcile_agent(args.agent_name, args.session, cwd, args.command, args.tracker_socket)
    except Exception as e:
        print(str(e), file=sys.stderr)
        return 1
    print(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
