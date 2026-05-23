import os
import sys
import json
from .common import call_rpc

def register(subparsers):
    parser = subparsers.add_parser("send-pane", help="Send a tmux pane snapshot to a target agent")
    parser.add_argument("target_address", help="Target agent address (e.g., 'alice', 'host-a/alice')")
    parser.add_argument("--source", help="Display name of the source agent to capture (defaults to self)")
    parser.add_argument("--id", help="ID of the source agent to capture")
    parser.add_argument("--pane", help="tmux pane ID of the source to capture (e.g., %%0)")
    parser.add_argument("--last", type=int, default=200, help="Number of history/scrollback lines to capture")
    parser.add_argument("--note", help="Optional custom note to attach to the snapshot")
    parser.add_argument(
        "--format",
        choices=["markdown", "json"],
        default="markdown",
        help="Message encapsulation format (markdown or json)"
    )
    parser.set_defaults(handler=handle)


def handle(args):
    # 1. Prepare capture payload parameter dictionary for source
    capture_params = {
        "last_lines": args.last,
        "include_ansi": False # We do not want ANSI codes in snapshots delivered to other agents
    }
    
    if args.source:
        capture_params["agent_name"] = args.source
    if args.id:
        capture_params["agent_id"] = args.id
    if args.pane:
        capture_params["tmux_pane"] = args.pane

    # If no source parameters are specified, capture_pane RPC will default to self-capture (caller_pid lookup)
    
    try:
        # 2. Fetch the source pane snapshot locally
        snapshot = call_rpc("capture_pane", capture_params)
        if not snapshot:
            print("Error: Failed to extract pane snapshot from agent-tracker.", file=sys.stderr)
            sys.exit(1)

        # 3. Format snapshot based on requested layout format
        if args.format == "json":
            payload = {
                "type": "pane_snapshot",
                "source_agent_name": snapshot.get("agent_name"),
                "source_agent_id": snapshot.get("agent_id"),
                "tmux_pane": snapshot.get("tmux_pane"),
                "session": snapshot.get("session"),
                "copy_mode": snapshot.get("copy_mode"),
                "captured_at": snapshot.get("captured_at"),
                "lines_requested": snapshot.get("lines_requested"),
                "note": args.note,
                "content": snapshot.get("content", "")
            }
            message_text = json.dumps(payload)
        else: # markdown
            note_block = ""
            if args.note:
                note_block = f"- **User Note:** {args.note}\n"
                
            source_display = snapshot.get("agent_name") or "Unnamed Agent"
            if snapshot.get("agent_id"):
                source_display += f" ({snapshot.get('agent_id')})"
                
            message_text = (
                f"### Pane Capture Snapshot from {source_display}\n"
                f"- **Pane:** {snapshot.get('tmux_pane') or 'unknown'}\n"
                f"- **Session:** {snapshot.get('session') or 'unknown'}\n"
                f"- **Copy Mode:** {'Active' if snapshot.get('copy_mode') else 'Inactive'}\n"
                f"- **Captured At:** {snapshot.get('captured_at')}\n"
                f"{note_block}"
                f"\n```\n"
                f"{snapshot.get('content', '')}\n"
                f"```\n"
            )

        # 4. Prepare send_message params
        send_params = {
            "message": message_text
        }
        if "/" in args.target_address:
            send_params["target_address"] = args.target_address
        elif len(args.target_address) == 36 and args.target_address.replace("-", "").isalnum():
            send_params["agent_id"] = args.target_address
        else:
            send_params["agent_name"] = args.target_address
        
        # Expose our own sender name if possible
        if "AGENT_ID" in os.environ:
            send_params["sender_id"] = os.environ["AGENT_ID"]
        elif "AGENT_NAME" in os.environ:
            send_params["sender_name"] = os.environ["AGENT_NAME"]

        # 5. Deliver the message via send_message RPC
        res = call_rpc("send_message", send_params)
        if res:
            print(f"Snapshot successfully sent to '{args.target_address}'.")
        else:
            print(f"Error: Failed to send snapshot to '{args.target_address}'.", file=sys.stderr)
            sys.exit(1)

    except Exception as e:
        print(f"Error executing send-pane: {e}", file=sys.stderr)
        sys.exit(1)
