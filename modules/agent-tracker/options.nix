{ lib, ... }:

with lib;

{
  options.services.agent-tracker = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable agent-tracker daemon";
    };

    enableTmuxIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Enable agent-related tmux configuration (status bar, keybindings)";
    };

    agents = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Map of agent aliases to their executable paths.";
    };

    pollInterval = mkOption {
      type = types.ints.positive;
      default = 5;
      description = "Monitor poll interval in seconds.";
    };

    heartbeatStaleSeconds = mkOption {
      type = types.ints.positive;
      default = 20;
      description = "Heartbeat age in seconds after which an agent becomes stale. Must be less than or equal to heartbeatGraceSeconds.";
    };

    heartbeatGraceSeconds = mkOption {
      type = types.ints.positive;
      default = 30;
      description = "Heartbeat age in seconds after which the monitor may evict an agent if no live pane process is found. Must be greater than or equal to heartbeatStaleSeconds.";
    };

    httpPort = mkOption {
      type = types.port;
      default = 19876;
      description = "HTTP sidecar port for observer/registry access.";
    };

    registryUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional agent-registry base URL.";
    };

    registryAuth = mkOption {
      type = types.bool;
      default = false;
      description = "Require Bearer auth for registry/sidecar integration.";
    };

    registryTokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "File containing the shared Bearer token for registry/sidecar auth.";
    };

    registryHeartbeatSeconds = mkOption {
      type = types.ints.positive;
      default = 30;
      description = "Registry heartbeat interval in seconds.";
    };
  };
}
