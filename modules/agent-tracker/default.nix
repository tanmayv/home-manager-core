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
    ];

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

    # Contribute tmux configuration if enabled
    programs.tmux.extraConfig = mkIf cfg.enableTmuxIntegration ''
      # Agent navigation contributed by agent-tracker extension
      bind-key N run-shell "agent-tracker-ctl focus --next"
      bind-key P run-shell "agent-tracker-ctl focus --prev"
    '';
  };
}
