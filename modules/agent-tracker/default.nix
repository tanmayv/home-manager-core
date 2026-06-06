{ pkgs, lib, config, userSettings ? {}, inputs, ... }:

with lib;

let
  cfg = config.services.agent-tracker;
  agentTrackerSettings = userSettings.agent-tracker or {};
  registryTokenFileFromSettings = let
    value = agentTrackerSettings.registry-token-file or null;
  in if value == "" then null else value;
in
{
  imports = [
    ./options.nix
    inputs.broccoli-comms.homeManagerModules.broccoli-comms
  ];

  config = mkMerge [
    {
      services.agent-tracker.enable = mkDefault (userSettings.enable-agent-tracker or false);
      services.agent-tracker.registries = mkDefault (agentTrackerSettings.registries or []);
      services.agent-tracker.registryAuth = mkDefault (agentTrackerSettings.registry-auth or false);
      services.agent-tracker.registryTokenFile = mkDefault registryTokenFileFromSettings;
      services.agent-tracker.httpPort = mkDefault (agentTrackerSettings.http-port or 19876);
      services.agent-tracker.registryHeartbeatSeconds = mkDefault (agentTrackerSettings.registry-heartbeat-seconds or 30);
      services.agent-tracker.enableReliableSendKeys = mkDefault (agentTrackerSettings.enable-reliable-send-keys or true);
      services.agent-tracker.capturePaneDefaultLines = mkDefault (agentTrackerSettings.capture-pane-default-lines or 25);
      services.agent-tracker.allowRemotePaneInput = mkDefault (agentTrackerSettings.allow-remote-pane-input or true);
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
        {
          assertion = cfg.registryUrl == null;
          message = "services.agent-tracker.registryUrl is deprecated. Please use services.agent-tracker.registries instead.";
        }
      ];

      warnings = [
        "services.agent-tracker is deprecated in home-manager-core; delegating to services.broccoli-comms.tracker so no standalone agent-tracker.service is created."
      ];

      services.broccoli-comms.enable = mkDefault true;
      services.broccoli-comms.tracker = {
        enable = mkDefault true;
        registries = mkDefault cfg.registries;
        registryAuth = mkDefault cfg.registryAuth;
        registryTokenFile = mkDefault cfg.registryTokenFile;
        httpPort = mkDefault cfg.httpPort;
        registryHeartbeatSeconds = mkDefault cfg.registryHeartbeatSeconds;
        enableReliableSendKeys = mkDefault cfg.enableReliableSendKeys;
        capturePaneDefaultLines = mkDefault cfg.capturePaneDefaultLines;
        remotePaneInput.enable = mkDefault cfg.allowRemotePaneInput;
      };

      home.packages = lib.mapAttrsToList (alias: command:
        pkgs.writeShellApplication {
          name = alias;
          runtimeInputs = [ config.programs.broccoli-comms.package ];
          text = ''
            exec ${config.programs.broccoli-comms.package}/bin/broccoli-comms track --name ${lib.escapeShellArg alias} -- ${lib.escapeShellArg command} "$@"
          '';
        }) cfg.agents;

      programs.tmux.statusBar.extraLines = mkIf cfg.enableTmuxIntegration [
        {
          name = "agents";
          command = "#(broccoli-comms agent-tracker status-bar '#{pane_id}')";
        }
      ];

      programs.tmux.extraConfig = mkIf cfg.enableTmuxIntegration ''
        # Agent navigation contributed by Broccoli Comms agent-tracker compatibility integration
        bind-key N run-shell "broccoli-comms agent-tracker focus --next"
        bind-key P run-shell "broccoli-comms agent-tracker focus --prev"
        bind-key -n MouseDown3Status if-shell -F '#{==:#{mouse_status_range},agent-registries}' \
          { display-popup -w 80% -h 40% -E "broccoli-comms agent-tracker registry-status; echo; printf 'Press Enter to close...'; read _" }
      '';
    })
  ];
}
