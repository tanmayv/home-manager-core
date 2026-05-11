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
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.writeScriptBin "agent-tracker-ctl" ''
        #!${pkgs.python3}/bin/python3
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
        ExecStart = "${pkgs.python3}/bin/python3 ${agentTrackerFiles}/agent-tracker.py";
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
  };
}
