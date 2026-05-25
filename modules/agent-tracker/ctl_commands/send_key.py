import sys

from .common import call_rpc, is_uuid


def register(subparsers):
    parser = subparsers.add_parser(
        "send-key",
        help="Send symbolic keys directly to a target agent pane",
        description=(
            "Send tmux-style symbolic keys directly into a local or remote agent pane, bypassing inbox delivery.\n"
            "Examples:\n"
            "  agent-tracker-ctl send-key alice ESC\n"
            "  agent-tracker-ctl send-key alice C-c Enter\n"
            "  agent-tracker-ctl send-key host-a/alice Escape\n"
            "\n"
            "Bare names/UUIDs are local-only. Use HOST/TARGET for registry-routed remote delivery."
        ),
    )
    parser.add_argument("target", metavar="TARGET", help="Local agent name/UUID or remote HOST/NAME_OR_UUID")
    parser.add_argument("keys", nargs="+", metavar="KEY", help="Symbolic tmux key token, e.g. ESC, Enter, C-c")
    parser.set_defaults(handler=handle)


def _apply_target(params, target):
    if "/" in target:
        params["target_address"] = target
    elif is_uuid(target):
        params["agent_id"] = target
    else:
        params["agent_name"] = target
    return params


def handle(args):
    params = _apply_target({
        "input_type": "keys",
        "keys": args.keys,
    }, args.target)

    res = call_rpc("send_input", params)
    if isinstance(res, dict) and not res.get("success", True):
        print(f"Error: {res.get('error', 'Direct key input failed')}", file=sys.stderr)
        sys.exit(1)

    print("Keys sent.")
