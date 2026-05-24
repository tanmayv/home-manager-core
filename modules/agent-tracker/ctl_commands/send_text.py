import sys

from .common import call_rpc, is_uuid


def register(subparsers):
    parser = subparsers.add_parser(
        "send-text",
        help="Type literal text directly into a target agent pane",
        description=(
            "Type literal text directly into a local or remote agent pane, bypassing inbox delivery.\n"
            "Examples:\n"
            "  agent-tracker-ctl send-text alice \"hello\"\n"
            "  agent-tracker-ctl send-text --no-submit alice \"draft\"\n"
            "  agent-tracker-ctl send-text host-a/alice \"hello\"\n"
            "\n"
            "Bare names/UUIDs are local-only. Use HOST/TARGET for registry-routed remote delivery."
        ),
    )
    parser.add_argument("target", metavar="TARGET", help="Local agent name/UUID or remote HOST/NAME_OR_UUID")
    parser.add_argument("text", help="Literal text to type into the target pane")
    parser.add_argument("--no-submit", action="store_true", help="Do not send Enter after typing the text")
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
        "input_type": "text",
        "text": args.text,
        "submit": not args.no_submit,
    }, args.target)

    res = call_rpc("send_input", params)
    if isinstance(res, dict) and not res.get("success", True):
        print(f"Error: {res.get('error', 'Direct text input failed')}", file=sys.stderr)
        sys.exit(1)

    print("Text sent.")
