{ pkgs, config }:

# Deprecated compatibility command. We no longer provide implicit tracking
# wrappers; agent commands must be launched explicitly through Broccoli Comms.
pkgs.writeShellApplication {
  name = "agent-wrapper";
  runtimeInputs = [ config.programs.broccoli-comms.package ];

  text = ''
    cat >&2 <<'EOF'
agent-wrapper is deprecated and no longer launches commands implicitly.
Use an explicit Broccoli Comms launch instead, for example:
  broccoli-comms run NAME --cwd "$PWD" -- COMMAND [ARGS...]
EOF
    exit 2
  '';
}
