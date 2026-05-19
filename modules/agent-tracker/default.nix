{ pkgs, lib, config, userSettings ? {}, ... }:

with lib;

let
  cfg = config.services.agent-tracker;
  agentTrackerFiles = pkgs.stdenv.mkDerivation {
    name = "agent-tracker-files";
    src = ./.;
    installPhase = ''
      mkdir -p $out
      cp -r * $out/
    '';
  };
  tmuxUserSettings = userSettings // lib.optionalAttrs (userSettings ? tmuxTheme) {
    theme = userSettings.tmuxTheme;
  };
  agentTrackerSettings = userSettings.agent-tracker or {};
  registryTokenFileFromSettings = let
    value = agentTrackerSettings.registry-token-file or null;
  in if value == "" then null else value;
  palette = import ../palette.nix { userSettings = tmuxUserSettings; };
  cacheHome = config.xdg.cacheHome or "${config.home.homeDirectory}/.cache";
  socketPath = "${cacheHome}/agent-tracker/agent-tracker.sock";
  logDir = "${cacheHome}/agent-tracker";
  launchdStdoutPath = "${logDir}/launchd.stdout.log";
  launchdStderrPath = "${logDir}/launchd.stderr.log";
  agentTrackerToolPath = lib.makeBinPath [ pkgs.tmux pkgs.coreutils pkgs.gnugrep ];
  platformFallbackPath =
    if pkgs.stdenv.isDarwin
    then "/usr/bin:/bin:/usr/sbin:/sbin"
    else "/run/current-system/sw/bin:/usr/local/bin:/usr/bin:/bin";
  daemonCmd = toString (pkgs.writeShellScript "agent-tracker-daemon" ''
    export AGENT_REGISTRY_AUTH=${if cfg.registryAuth then "true" else "false"}
    ${lib.optionalString (cfg.registryAuth && cfg.registryTokenFile != null) ''export AGENT_REGISTRY_TOKEN="$(cat ${lib.escapeShellArg (toString cfg.registryTokenFile)})"''}
    exec ${pkgs.python3}/bin/python3 ${agentTrackerFiles}/agent-tracker.py
  '');
  agentWrapperPackage = import ../scripts/agent-wrapper-package.nix { inherit pkgs config; };
  monitorEnvVars = {
    AGENT_TRACKER_SOCKET = socketPath;
    POLL_INTERVAL = toString cfg.pollInterval;
    HEARTBEAT_STALE_SECONDS = toString cfg.heartbeatStaleSeconds;
    HEARTBEAT_GRACE_SECONDS = toString cfg.heartbeatGraceSeconds;
    AGENT_TRACKER_HTTP_PORT = toString cfg.httpPort;
    AGENT_REGISTRY_HEARTBEAT_SECONDS = toString cfg.registryHeartbeatSeconds;
    AGENT_REGISTRY_AUTH = if cfg.registryAuth then "true" else "false";
    # systemd user services and launchd agents both start with a minimal PATH.
    # agent-tracker intentionally invokes `tmux` and `sleep` by name from
    # Python, so provide an explicit cross-platform tool PATH instead of
    # relying on the interactive shell environment.
    PATH = "${agentTrackerToolPath}:${platformFallbackPath}";
  } // lib.optionalAttrs (cfg.registryUrl != null && cfg.registries == []) {
    AGENT_REGISTRY_URL = cfg.registryUrl;
  } // lib.optionalAttrs (cfg.registries != []) {
    AGENT_REGISTRIES_JSON = builtins.toJSON cfg.registries;
  };
  monitorEnv = lib.mapAttrsToList (name: value: "${name}=${value}") monitorEnvVars;
in
{
  imports = [
    ./options.nix
  ];

  config = mkMerge [
    {
      services.agent-tracker.enable = mkDefault (userSettings.enable-agent-tracker or false);
      services.agent-tracker.registryUrl = mkDefault (agentTrackerSettings.registry-url or null);
      services.agent-tracker.registries = mkDefault (agentTrackerSettings.registries or []);
      services.agent-tracker.registryAuth = mkDefault (agentTrackerSettings.registry-auth or false);
      services.agent-tracker.registryTokenFile = mkDefault registryTokenFileFromSettings;
      services.agent-tracker.httpPort = mkDefault (agentTrackerSettings.http-port or 19876);
      services.agent-tracker.registryHeartbeatSeconds = mkDefault (agentTrackerSettings.registry-heartbeat-seconds or 30);
    }

    (mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.heartbeatGraceSeconds >= cfg.heartbeatStaleSeconds;
          message = "services.agent-tracker.heartbeatGraceSeconds must be greater than or equal to services.agent-tracker.heartbeatStaleSeconds.";
        }
        {
          assertion = !cfg.registryAuth || cfg.registryTokenFile != null;
          message = "services.agent-tracker.registryTokenFile is required when registryAuth is enabled.";
        }
      ];

      home.activation.ensureAgentTrackerCacheDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p ${lib.escapeShellArg logDir}
      '';

      home.packages = [
        agentWrapperPackage
        (pkgs.writeScriptBin "agent-tracker-ctl" ''
          #!${pkgs.python3}/bin/python3
          import os
          os.environ.setdefault("AGENT_TRACKER_SOCKET", "${socketPath}")
          ${lib.optionalString (!cfg.enable) ''os.environ.setdefault("AGENT_TRACKER_DAEMON", "${daemonCmd}")''}
          os.environ.setdefault("POLL_INTERVAL", "${toString cfg.pollInterval}")
          os.environ.setdefault("HEARTBEAT_STALE_SECONDS", "${toString cfg.heartbeatStaleSeconds}")
          os.environ.setdefault("HEARTBEAT_GRACE_SECONDS", "${toString cfg.heartbeatGraceSeconds}")
          os.environ.setdefault("AGENT_TRACKER_HTTP_PORT", "${toString cfg.httpPort}")
          os.environ.setdefault("AGENT_REGISTRY_HEARTBEAT_SECONDS", "${toString cfg.registryHeartbeatSeconds}")
          os.environ.setdefault("AGENT_REGISTRY_AUTH", "${if cfg.registryAuth then "true" else "false"}")
          ${lib.optionalString (cfg.registryUrl != null && cfg.registries == []) ''os.environ.setdefault("AGENT_REGISTRY_URL", "${cfg.registryUrl}")''}
          ${lib.optionalString (cfg.registryTokenFile != null && cfg.registries == []) ''os.environ.setdefault("AGENT_REGISTRY_TOKEN", open(${builtins.toJSON (toString cfg.registryTokenFile)}).read().strip())''}
          ${lib.optionalString (cfg.registries != []) ''os.environ.setdefault("AGENT_REGISTRIES_JSON", ${builtins.toJSON (builtins.toJSON cfg.registries)})''}
          os.environ.setdefault("PALETTE_COLOR8", "${palette.color8}")
          os.environ.setdefault("PALETTE_COLOR1", "${palette.color1}")
          os.environ.setdefault("PALETTE_COLOR3", "${palette.color3}")
          os.environ.setdefault("PALETTE_COLOR6", "${palette.color6}")
          os.environ.setdefault("PALETTE_COLOR2", "${palette.color2}")
          os.environ.setdefault("PALETTE_COLOR4", "${palette.color4}")
          ${builtins.readFile ./agent-tracker-ctl.py}
        '')
      ] ++ (lib.mapAttrsToList (alias: path:
        pkgs.writeShellApplication {
          name = alias;
          runtimeInputs = [ agentWrapperPackage ];
          text = ''
            ${agentWrapperPackage}/bin/agent-wrapper "${path}" "$@"
          '';
        }
      ) cfg.agents);

      programs.tmux.statusBar.extraLines = mkIf cfg.enableTmuxIntegration [
        {
          name = "agents";
          command = "#(agent-tracker-ctl status-bar '#{pane_id}')";
        }
      ];

      # Contribute tmux configuration if enabled
      programs.tmux.extraConfig = mkIf cfg.enableTmuxIntegration ''
        # Agent navigation contributed by agent-tracker extension
        bind-key N run-shell "agent-tracker-ctl focus --next"
        bind-key P run-shell "agent-tracker-ctl focus --prev"
        bind-key -n MouseDown3Status if-shell -F '#{==:#{mouse_status_range},agent-registries}' \
          { display-popup -w 80% -h 40% -E "agent-tracker-ctl registry-status; echo; printf 'Press Enter to close...'; read _" }
      '';
    })

    (mkIf (cfg.enable && pkgs.stdenv.isLinux) {
      systemd.user.services.agent-tracker = {
        Unit = {
          Description = "Agent Tracker Daemon";
          StartLimitIntervalSec = 60;
          StartLimitBurst = 10;
        };
        Service = {
          Environment = monitorEnv;
          ExecStart = daemonCmd;
          Restart = "always";
          RestartSec = 2;
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    })

    (mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
      launchd.agents.agent-tracker = {
        enable = true;
        config = {
          ProgramArguments = [ "${daemonCmd}" ];
          EnvironmentVariables = monitorEnvVars;
          KeepAlive = false;
          ProcessType = "Background";
          RunAtLoad = true;
          StandardOutPath = launchdStdoutPath;
          StandardErrorPath = launchdStderrPath;
        };
      };
    })
  ];
}
