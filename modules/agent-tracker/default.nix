{ pkgs, lib, config, ... }:

with lib;

let
  cfg = config.services.agent-tracker;
in
{
  options.services.agent-tracker = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable agent-tracker daemon";
    };
  };

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
        ExecStart = "${pkgs.writeScriptBin "agent-tracker" ''
          #!${pkgs.python3}/bin/python3
          ${builtins.readFile ./agent-tracker.py}
        ''}/bin/agent-tracker";
        Restart = "always";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
