{ pkgs, lib, config, userSettings ? {}, inputs, ... }:
let
  agentTrackerSettings = userSettings.agent-tracker or {};
  registryTokenFileFromSettings = let
    value = agentTrackerSettings.registry-token-file or null;
  in if value == "" then null else value;
  cacheHome = config.xdg.cacheHome or "${config.home.homeDirectory}/.cache";
  configHome = config.xdg.configHome or "${config.home.homeDirectory}/.config";
  # Leave Broccoli Comms on its canonical app-owned runtime by default
  # (${XDG_RUNTIME_DIR:-/tmp/$UID}/broccoli-comms).  Only pin the runtime
  # when the user explicitly requests one; otherwise wrappers, the service,
  # and the UI all converge on the same Broccoli-managed daemon.
  broccoliRuntimeDir = agentTrackerSettings.runtime-dir or null;
  broccoliTrackerSocket = if broccoliRuntimeDir == null then "" else "${broccoliRuntimeDir}/agent-tracker.sock";
  legacyAgentTracker = config.services.agent-tracker;
  enableAgentTracker = (userSettings.enable-agent-tracker or false) || legacyAgentTracker.enable;
  enableAgentTrackerTmuxIntegration = legacyAgentTracker.enableTmuxIntegration && (agentTrackerSettings.enable-tmux-integration or true);
in
{
  imports = [
    ./modules/tmux
    ./modules/tmux-palette.nix
    ./modules/terminal
    ./modules/scripts
    ./modules/agent-tracker/options.nix
    inputs.broccoli-comms.homeManagerModules.broccoli-comms
    ({ config, lib, pkgs, ... }: {
      # Backward-compatible surface for extensions that still contribute
      # agent aliases through services.agent-tracker.*. Broccoli Comms owns
      # the tracker/registry runtime; this shim only turns legacy agents into
      # `broccoli-comms track` launchers pinned to the app-owned runtime.
      config.home.packages = lib.mkIf config.services.broccoli-comms.tracker.enable (
        lib.mapAttrsToList (alias: command:
          pkgs.writeShellApplication {
            name = alias;
            runtimeInputs = [ config.programs.broccoli-comms.package ];
            text = ''
              exec ${config.programs.broccoli-comms.package}/bin/broccoli-comms track --name ${lib.escapeShellArg alias} -- ${lib.escapeShellArg command} "$@"
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
    runtimeDir = lib.mkDefault broccoliRuntimeDir;
    cacheDir = lib.mkDefault "${cacheHome}/broccoli-comms";
    configDir = lib.mkDefault "${configHome}/broccoli-comms";
    tracker = {
      enable = lib.mkDefault enableAgentTracker;
      hostname = lib.mkDefault (agentTrackerSettings.hostname or null);
      registries = lib.mkDefault (if legacyAgentTracker.registries != [] then legacyAgentTracker.registries else (agentTrackerSettings.registries or []));
      registryAuth = lib.mkDefault (legacyAgentTracker.registryAuth || (agentTrackerSettings.registry-auth or false));
      registryTokenFile = lib.mkDefault (if legacyAgentTracker.registryTokenFile != null then legacyAgentTracker.registryTokenFile else registryTokenFileFromSettings);
      tmuxSocketPath = lib.mkDefault (agentTrackerSettings.tmux-socket-path or null);
      httpPort = lib.mkDefault (if legacyAgentTracker.httpPort != 19876 then legacyAgentTracker.httpPort else (agentTrackerSettings.http-port or 19876));
      registryHeartbeatSeconds = lib.mkDefault (if legacyAgentTracker.registryHeartbeatSeconds != 30 then legacyAgentTracker.registryHeartbeatSeconds else (agentTrackerSettings.registry-heartbeat-seconds or 30));
      enableReliableSendKeys = lib.mkDefault (legacyAgentTracker.enableReliableSendKeys && (agentTrackerSettings.enable-reliable-send-keys or true));
      capturePaneDefaultLines = lib.mkDefault (if legacyAgentTracker.capturePaneDefaultLines != 25 then legacyAgentTracker.capturePaneDefaultLines else (agentTrackerSettings.capture-pane-default-lines or 25));
      remotePaneInput.enable = lib.mkDefault (legacyAgentTracker.allowRemotePaneInput && (agentTrackerSettings.allow-remote-pane-input or true));
    };
  };

  programs.tmux.statusBar.extraLines = lib.mkIf (config.services.broccoli-comms.tracker.enable && enableAgentTrackerTmuxIntegration) [
    {
      name = "agents";
      command = "#(broccoli-comms agent-tracker status-bar '#{pane_id}')";
    }
  ];

  programs.tmux.extraConfig = lib.mkIf (config.services.broccoli-comms.tracker.enable && enableAgentTrackerTmuxIntegration) ''
    # Agent navigation contributed by Broccoli Comms agent-tracker integration
    bind-key N run-shell "broccoli-comms agent-tracker focus --next"
    bind-key P run-shell "broccoli-comms agent-tracker focus --prev"
    bind-key -n MouseDown3Status if-shell -F '#{==:#{mouse_status_range},agent-registries}' \
      { display-popup -w 80% -h 40% -E "broccoli-comms agent-tracker registry-status; echo; printf 'Press Enter to close...'; read _" }
  '';

  services.agent-communicator-web.enable = lib.mkDefault true;
  services.agent-communicator-web.socket = lib.mkDefault broccoliTrackerSocket;
}
