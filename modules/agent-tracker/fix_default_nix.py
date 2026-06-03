import re

with open("default.nix", "r") as f:
    content = f.read()

toml_generation = '''
      xdg.configFile."broccoli-comms/config.toml" = mkIf cfg.enable {
        text = let
          tomlStr = lib.generators.toTOML {} {
            tracker = {
              poll_interval_seconds = cfg.pollInterval;
              heartbeat_stale_seconds = cfg.heartbeatStaleSeconds;
              heartbeat_grace_seconds = cfg.heartbeatGraceSeconds;
              registry_port = cfg.httpPort;
            };
            registry = {
              heartbeat_seconds = cfg.registryHeartbeatSeconds;
              auth_enabled = cfg.registryAuth;
              registries = cfg.registries;
            };
            ui = {
              capture_pane_default_lines = cfg.capturePaneDefaultLines;
              remote_pane_input_enabled = cfg.allowRemotePaneInput;
            };
            paths = {
              agent_tracker_socket = socketPath;
            };
          };
        in tomlStr;
      };
'''

content = content.replace("  config = mkMerge [", "  config = mkMerge [\n" + toml_generation)

content = re.sub(
    r'        agentWrapperPackage.*?\[ agentWrapperPackage \];',
    r'        agentWrapperPackage\n      ] ++ (lib.mapAttrsToList (alias: path:\n        pkgs.writeShellApplication {\n          name = alias;\n          runtimeInputs = [ agentWrapperPackage ];',
    content,
    flags=re.DOTALL
)

# Remove environment variable passes from agent-tracker-ctl
content = re.sub(r'os\.environ\.setdefault\("AGENT_TRACKER_SOCKET".*?\n', '', content)
content = re.sub(r'os\.environ\.setdefault\("AGENT_TRACKER_DAEMON".*?\n', '', content)
content = re.sub(r'os\.environ\.setdefault\("POLL_INTERVAL".*?\n', '', content)
content = re.sub(r'os\.environ\.setdefault\("HEARTBEAT_STALE_SECONDS".*?\n', '', content)
content = re.sub(r'os\.environ\.setdefault\("HEARTBEAT_GRACE_SECONDS".*?\n', '', content)
content = re.sub(r'os\.environ\.setdefault\("AGENT_TRACKER_HTTP_PORT".*?\n', '', content)
content = re.sub(r'os\.environ\.setdefault\("AGENT_REGISTRY_HEARTBEAT_SECONDS".*?\n', '', content)
content = re.sub(r'os\.environ\.setdefault\("AGENT_REGISTRY_AUTH".*?\n', '', content)
content = re.sub(r'os\.environ\.setdefault\("ENABLE_RELIABLE_SEND_KEYS".*?\n', '', content)
content = re.sub(r'os\.environ\.setdefault\("AGENT_TRACKER_CAPTURE_PANE_DEFAULT_LINES".*?\n', '', content)
content = re.sub(r'os\.environ\.setdefault\("AGENT_TRACKER_ALLOW_REMOTE_PANE_INPUT".*?\n', '', content)
content = re.sub(r'os\.environ\.setdefault\("AGENT_REGISTRIES_JSON".*?\n', '', content)

with open("default.nix", "w") as f:
    f.write(content)
