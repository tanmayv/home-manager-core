{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.agent-communicator-web;

  agent-communicator-web-pkg = pkgs.buildGoModule {
    pname = "agent-communicator-web";
    version = "1.0.0";
    src = ./../agent-communicator-web;

    # No external module dependencies
    vendorHash = null;
  };
in
{
  options.services.agent-communicator-web = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the agent communicator web interface.";
    };

    port = mkOption {
      type = types.port;
      default = 8282;
      description = "Listening port for the agent communicator web interface.";
    };

    socket = mkOption {
      type = types.str;
      default = "";
      description = "Path to agent-tracker Unix domain socket. If empty, client auto-discovers.";
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.agent-communicator-web = {
      Unit = {
        Description = "Agent Communicator Web";
        After = [ "network.target" ];
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
      Service = {
        ExecStart = "${agent-communicator-web-pkg}/bin/agent-communicator-web -port ${toString cfg.port}" + (optionalString (cfg.socket != "") " -socket ${cfg.socket}");
        Restart = "always";
        RestartSec = "5s";
      };
    };
  };
}
