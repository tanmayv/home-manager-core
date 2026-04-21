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
    systemd.user.services.agent-tracker = {
      Unit = {
        Description = "Agent Tracker Daemon";
      };
      Service = {
        ExecStart = "${pkgs.writeShellScript "agent-tracker" ''
          #!/bin/bash
          while true; do
            echo "Agent Tracker is running" >> /tmp/agent-tracker.log
            sleep 10
          done
        ''}";
        Restart = "always";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
