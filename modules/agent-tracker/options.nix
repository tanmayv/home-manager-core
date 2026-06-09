{ lib, ... }:

with lib;

{
  options.services.agent-tracker = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Deprecated compatibility alias for services.broccoli-comms.tracker.enable.";
    };

    enableTmuxIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Deprecated compatibility flag for Broccoli Comms tracker tmux integration (status bar, keybindings).";
    };

    agents = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Deprecated compatibility metadata for named agent commands. No shell wrappers are generated; launch explicitly with `broccoli-comms run NAME --cwd DIR -- COMMAND [ARGS...]`.";
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
      description = "DEPRECATED: Optional agent-registry base URL. Please use services.agent-tracker.registries instead.";
    };

    registries = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Short name for this agent registry.";
          };
          url = mkOption {
            type = types.str;
            description = "Agent registry base URL.";
          };
          token-file = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Optional file containing the Bearer token for this registry.";
          };
        };
      });
      default = [];
      description = "Optional list of agent registries used for discovery, sync, and remote delivery.";
    };

    registryAuth = mkOption {
      type = types.bool;
      default = false;
      description = "Require shared Bearer auth for registry/sidecar integration.";
    };

    registryTokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "File containing the shared Bearer token for registry/sidecar auth and as the default token for registry entries without token-file.";
    };

    registryHeartbeatSeconds = mkOption {
      type = types.ints.positive;
      default = 30;
      description = "Registry heartbeat interval in seconds.";
    };

    enableReliableSendKeys = mkOption {
      type = types.bool;
      default = true;
      description = "Enable tmux send-keys delivery verification and advisory copy-mode cancellation.";
    };

    capturePaneDefaultLines = mkOption {
      type = types.ints.positive;
      default = 25;
      description = "Default number of tmux pane history lines captured by agent-tracker capture-pane and send-pane commands when --last is omitted.";
    };

    allowRemotePaneInput = mkOption {
      type = types.bool;
      default = true;
      description = "Allow registry-routed remote direct pane input (send-text/send-key). Local direct pane input remains available.";
    };
  };
}
