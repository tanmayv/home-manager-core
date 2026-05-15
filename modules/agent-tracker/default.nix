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
  palette = import ../palette.nix { userSettings = tmuxUserSettings; };
  cacheHome = config.xdg.cacheHome or "${config.home.homeDirectory}/.cache";
  socketPath = "${cacheHome}/agent-tracker/agent-tracker.sock";
  logDir = "${cacheHome}/agent-tracker";
  launchdStdoutPath = "${logDir}/launchd.stdout.log";
  launchdStderrPath = "${logDir}/launchd.stderr.log";
  daemonCmd = "${pkgs.python3}/bin/python3 ${agentTrackerFiles}/agent-tracker.py";
  agentWrapperPackage = import ../scripts/agent-wrapper-package.nix { inherit pkgs config; };
  monitorEnvVars = {
    AGENT_TRACKER_SOCKET = socketPath;
    POLL_INTERVAL = toString cfg.pollInterval;
    HEARTBEAT_STALE_SECONDS = toString cfg.heartbeatStaleSeconds;
    HEARTBEAT_GRACE_SECONDS = toString cfg.heartbeatGraceSeconds;
  } // lib.optionalAttrs pkgs.stdenv.isDarwin {
    # launchd starts services with a minimal PATH, so bare `tmux` lookups from
    # the daemon fail on macOS unless we provide the Nix profile tool paths.
    PATH = "${lib.makeBinPath [ pkgs.tmux pkgs.coreutils pkgs.gnugrep ]}:/usr/bin:/bin:/usr/sbin:/sbin";
  };
  monitorEnv = lib.mapAttrsToList (name: value: "${name}=${value}") monitorEnvVars;
in
{
  imports = [
    ./options.nix
  ];

  config = mkMerge [
    (mkIf cfg.enable {
      assertions = [
        {
          assertion = cfg.heartbeatGraceSeconds >= cfg.heartbeatStaleSeconds;
          message = "services.agent-tracker.heartbeatGraceSeconds must be greater than or equal to services.agent-tracker.heartbeatStaleSeconds.";
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
          os.environ.setdefault("AGENT_TRACKER_DAEMON", "${daemonCmd}")
          os.environ.setdefault("POLL_INTERVAL", "${toString cfg.pollInterval}")
          os.environ.setdefault("HEARTBEAT_STALE_SECONDS", "${toString cfg.heartbeatStaleSeconds}")
          os.environ.setdefault("HEARTBEAT_GRACE_SECONDS", "${toString cfg.heartbeatGraceSeconds}")
          os.environ.setdefault("PALETTE_COLOR8", "${palette.color8}")
          os.environ.setdefault("PALETTE_COLOR1", "${palette.color1}")
          os.environ.setdefault("PALETTE_COLOR3", "${palette.color3}")
          os.environ.setdefault("PALETTE_COLOR6", "${palette.color6}")
          os.environ.setdefault("PALETTE_COLOR2", "${palette.color2}")
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
          command = "#[fg=${palette.color4},bold] Active Agents: #[fg=${palette.color8},nobold]#(agent-tracker-ctl status-bar)";
          condition = "[ $(agent-tracker-ctl list | python3 -c 'import sys, json; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0) -gt 0 ]";
        }
      ];

      # Contribute tmux configuration if enabled
      programs.tmux.extraConfig = mkIf cfg.enableTmuxIntegration ''
        # Agent navigation contributed by agent-tracker extension
        bind-key N run-shell "agent-tracker-ctl focus --next"
        bind-key P run-shell "agent-tracker-ctl focus --prev"
      '';
    })

    (mkIf (cfg.enable && pkgs.stdenv.isLinux) {
      systemd.user.services.agent-tracker = {
        Unit = {
          Description = "Agent Tracker Daemon";
        };
        Service = {
          Environment = monitorEnv;
          ExecStart = daemonCmd;
          Restart = "always";
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
          ProgramArguments = [ "${pkgs.python3}/bin/python3" "${agentTrackerFiles}/agent-tracker.py" ];
          EnvironmentVariables = monitorEnvVars;
          KeepAlive = {
            Crashed = true;
            SuccessfulExit = false;
          };
          ProcessType = "Background";
          RunAtLoad = true;
          StandardOutPath = launchdStdoutPath;
          StandardErrorPath = launchdStderrPath;
        };
      };
    })
  ];
}
