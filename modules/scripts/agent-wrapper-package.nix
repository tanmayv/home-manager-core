{ pkgs, config }:

# Compatibility shim only. The canonical wrapper/tracker lives inside the
# Broccoli Comms runtime; keep the historical `agent-wrapper <cmd> [args...]`
# command name for older scripts, but delegate to `broccoli-comms track` so no
# standalone/global tracker is started or used.
pkgs.writeShellApplication {
  name = "agent-wrapper";
  runtimeInputs = [ config.programs.broccoli-comms.package ];

  text = ''
    if [[ $# -lt 1 ]]; then
      echo "usage: agent-wrapper <command> [args...]" >&2
      exit 2
    fi

    cmd="$1"
    shift
    suggested_name="''${SUGGESTED_AGENT_NAME:-$(basename "$cmd")}"
    exec broccoli-comms track --name "$suggested_name" -- "$cmd" "$@"
  '';
}
