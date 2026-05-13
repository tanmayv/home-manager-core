{ pkgs, lib, config, ... }:

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
  palette = import ../palette.nix;
  cacheHome = config.xdg.cacheHome or "${config.home.homeDirectory}/.cache";
  socketPath = "${cacheHome}/agent-tracker/agent-tracker.sock";
  daemonCmd = "${pkgs.python3}/bin/python3 ${agentTrackerFiles}/agent-tracker.py";
in
{
  imports = [
    ./options.nix
  ];

  config = mkMerge [
    (mkIf (cfg.enable && pkgs.stdenv.isLinux) {
      home.packages = [
        (pkgs.writeScriptBin "agent-tracker-ctl" ''
          #!${pkgs.python3}/bin/python3
          import os
          os.environ.setdefault("AGENT_TRACKER_SOCKET", "${socketPath}")
          os.environ.setdefault("AGENT_TRACKER_DAEMON", "${daemonCmd}")
          ${builtins.readFile ./agent-tracker-ctl.py}
        '')
      ] ++ (lib.mapAttrsToList (alias: path: 
        pkgs.writeShellApplication {
          name = alias;
          text = ''
            agent-wrapper "${path}" "$@"
          '';
        }
      ) cfg.agents);

      systemd.user.services.agent-tracker = {
        Unit = {
          Description = "Agent Tracker Daemon";
        };
        Service = {
          Environment = [ "AGENT_TRACKER_SOCKET=${socketPath}" ];
          ExecStart = daemonCmd;
          Restart = "always";
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };

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

    (mkIf (cfg.enable && !pkgs.stdenv.isLinux) {
      warnings = [
        "services.agent-tracker is currently Linux-only; it will not be started on this platform."
      ];
    })
  ];
}
