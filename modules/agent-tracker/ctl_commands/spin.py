import argparse
import os
import shlex
import sys

from .common import call_rpc, spin_session_name


def register(subparsers):
    parser = subparsers.add_parser("spin", help="Spin a new agent in a tmux session for a directory")
    parser.add_argument("directory", help="Working directory; leaf name becomes the tmux session/agent base name")
    parser.add_argument("agent_command", help="Agent command to run")
    parser.add_argument("agent_args", nargs=argparse.REMAINDER, help="Arguments for the agent command")
    parser.set_defaults(handler=handle)


def handle(args):
    directory = os.path.abspath(os.path.expanduser(args.directory))
    if not os.path.isdir(directory):
        print(f"Error: directory does not exist: {directory}", file=sys.stderr)
        sys.exit(1)
    session = spin_session_name(directory)
    command = shlex.join([args.agent_command] + args.agent_args)
    resolved_name = call_rpc("spin_agent", {"session": session, "directory": directory, "command": command, "name": session})
    if resolved_name:
        print(f"Agent spun successfully as: {resolved_name} in session: {session}")
