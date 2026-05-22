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

  cacheHome = config.xdg.cacheHome or "${config.home.homeDirectory}/.cache";
  logDir = "${cacheHome}/agent-communicator-web";
  launchdStdoutPath = "${logDir}/launchd.stdout.log";
  launchdStderrPath = "${logDir}/launchd.stderr.log";
  programArgs = [
    "${agent-communicator-web-pkg}/bin/agent-communicator-web"
    "-port"
    (toString cfg.port)
  ] ++ optionals (cfg.socket != "") [ "-socket" cfg.socket ];
  execStart = concatStringsSep " " programArgs;
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

  config = mkIf cfg.enable (mkMerge [
    {
      home.activation.ensureAgentCommunicatorWebLogDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p ${escapeShellArg logDir}
      '';
    }

    (mkIf pkgs.stdenv.isLinux {
      systemd.user.services.agent-communicator-web = {
        Unit = {
          Description = "Agent Communicator Web";
          After = [ "network.target" ];
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
        Service = {
          ExecStart = execStart;
          Restart = "always";
          RestartSec = "5s";
        };
      };
    })

    (mkIf pkgs.stdenv.isDarwin {
      home.activation.restartAgentCommunicatorWeb = lib.hm.dag.entryAfter [ "setupLaunchAgents" ] ''
        label="org.nix-community.home.agent-communicator-web"
        domain="gui/$(id -u)"
        service="$domain/$label"
        plist="$HOME/Library/LaunchAgents/$label.plist"

        echo "Force restarting $label"
        if [ -f "$plist" ]; then
          /bin/launchctl bootout "$service" >/dev/null 2>&1 || true
          for _ in 1 2 3 4 5; do
            if ! /bin/launchctl print "$service" >/dev/null 2>&1; then
              break
            fi
            /bin/sleep 1
          done
          if ! /bin/launchctl bootstrap "$domain" "$plist" >/dev/null 2>&1; then
            echo "launchctl bootstrap failed for $service; trying kickstart"
          fi
          if ! /bin/launchctl kickstart -k "$service" >/dev/null 2>&1; then
            echo "launchctl kickstart failed for $service"
          fi
        else
          echo "LaunchAgent plist not found: $plist"
        fi
      '';

      launchd.agents.agent-communicator-web = {
        enable = true;
        config = {
          ProgramArguments = programArgs;
          KeepAlive = true;
          ProcessType = "Background";
          RunAtLoad = true;
          StandardOutPath = launchdStdoutPath;
          StandardErrorPath = launchdStderrPath;
        };
      };
    })
  ]);
}
