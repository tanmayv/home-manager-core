{ pkgs, lib, config, userSettings ? {}, inputs, ... }:
let
  agentTrackerSettings = userSettings.agent-tracker or {};
  registryTokenFileFromSettings = let
    value = agentTrackerSettings.registry-token-file or null;
  in if value == "" then null else value;
  cacheHome = config.xdg.cacheHome or "${config.home.homeDirectory}/.cache";
  enableAgentTracker = (userSettings.enable-agent-tracker or false) || config.services.agent-tracker.enable;
  enableAgentTrackerTmuxIntegration = config.services.agent-tracker.enableTmuxIntegration && (agentTrackerSettings.enable-tmux-integration or true);
in
{
  imports = [
    ./modules/tmux
    ./modules/tmux-palette.nix
    ./modules/terminal
    ./modules/scripts
    inputs.broccoli-comms.homeManagerModules.broccoli-comms
    ({ config, lib, pkgs, ... }:
      let
        agentWrapperPackage = import ./modules/scripts/agent-wrapper-package.nix { inherit pkgs config; };
      in {
        # Backward-compatible surface for extensions that still contribute
        # agent aliases through services.agent-tracker.*. Broccoli Comms owns
        # the tracker daemon now; this shim only accepts legacy settings and
        # turns services.agent-tracker.agents into wrapper commands.
        options.services.agent-tracker = with lib; {
          enable = mkOption { type = types.bool; default = false; description = "Deprecated compatibility alias for services.broccoli-comms.tracker.enable."; };
          enableTmuxIntegration = mkOption { type = types.bool; default = true; description = "Deprecated compatibility flag for tmux tracker integration."; };
          agents = mkOption { type = types.attrsOf types.str; default = {}; description = "Deprecated map of agent aliases to commands wrapped with agent-wrapper."; };
        };

        config.home.packages = lib.mkIf config.services.broccoli-comms.tracker.enable (
          lib.mapAttrsToList (alias: command:
            pkgs.writeShellApplication {
              name = alias;
              runtimeInputs = [ agentWrapperPackage ];
              text = ''
                exec ${agentWrapperPackage}/bin/agent-wrapper ${lib.escapeShellArg command} "$@"
              '';
            }) config.services.agent-tracker.agents
        );
      })
    ./modules/agent-communicator-web.nix
    ./modules/git
  ] ++ (if userSettings.enable_bash_over_zsh or false then [ ./modules/bash ] else [ ./modules/zsh ])
    ++ (if userSettings.enable-ai-workflow or false then [ ./modules/ai-workflow ] else [])
    ++ (if userSettings.enable-neovim or false then [ inputs.nvim-nix.homeManagerModules.default ] else [])
    ++ (if userSettings.import-extras or false then [ ./modules/extras ] else []);

  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # Required for Home Manager to setup environment variables on non-NixOS Linux.
  targets.genericLinux.enable = pkgs.stdenv.isLinux;

  # You can customize the status bar position here
  programs.tmux.statusBarPosition = "bottom";

  home.packages = with pkgs; [
    fzf
    gawk
    git
    ripgrep
    bat
    pure-prompt
  ];

  programs.broccoli-comms.install = {
    # home-manager-core still provides these user-facing wrappers/TUI scripts;
    # Broccoli supplies the tracker/ctl/registry implementations.
    wrapper = lib.mkDefault false;
    tui = lib.mkDefault false;
    electron = lib.mkDefault (userSettings.enable-agent-communicator-electron or false);
  };

  services.broccoli-comms = {
    enable = lib.mkDefault enableAgentTracker;
    tracker = {
      enable = lib.mkDefault enableAgentTracker;
      hostname = lib.mkDefault (agentTrackerSettings.hostname or null);
      # Preserve the historical home-manager-core socket so existing scripts and
      # CLIs continue to work without setting AGENT_TRACKER_SOCKET.
      cacheDir = lib.mkDefault "${cacheHome}/agent-tracker";
      socketPath = lib.mkDefault "${cacheHome}/agent-tracker/agent-tracker.sock";
      registries = lib.mkDefault (agentTrackerSettings.registries or []);
      registryAuth = lib.mkDefault (agentTrackerSettings.registry-auth or false);
      registryTokenFile = lib.mkDefault registryTokenFileFromSettings;
      tmuxSocketPath = lib.mkDefault (agentTrackerSettings.tmux-socket-path or null);
      httpPort = lib.mkDefault (agentTrackerSettings.http-port or 19876);
      registryHeartbeatSeconds = lib.mkDefault (agentTrackerSettings.registry-heartbeat-seconds or 30);
      enableReliableSendKeys = lib.mkDefault (agentTrackerSettings.enable-reliable-send-keys or true);
      capturePaneDefaultLines = lib.mkDefault (agentTrackerSettings.capture-pane-default-lines or 25);
    };
  };

  programs.tmux.statusBar.extraLines = lib.mkIf (config.services.broccoli-comms.tracker.enable && enableAgentTrackerTmuxIntegration) [
    {
      name = "agents";
      command = "#(agent-tracker-ctl status-bar '#{pane_id}')";
    }
  ];

  programs.tmux.extraConfig = lib.mkIf (config.services.broccoli-comms.tracker.enable && enableAgentTrackerTmuxIntegration) ''
    # Agent navigation contributed by Broccoli Comms agent-tracker integration
    bind-key N run-shell "agent-tracker-ctl focus --next"
    bind-key P run-shell "agent-tracker-ctl focus --prev"
    bind-key -n MouseDown3Status if-shell -F '#{==:#{mouse_status_range},agent-registries}' \
      { display-popup -w 80% -h 40% -E "agent-tracker-ctl registry-status; echo; printf 'Press Enter to close...'; read _" }
  '';

  services.agent-communicator-web.enable = lib.mkDefault true;
}
