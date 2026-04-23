{ pkgs, lib, config, userSettings, ... }: {
  imports = [
    ./modules/tmux
    ./modules/hg.nix
    ./modules/tmux-palette.nix
    ./modules/scripts
  ] ++ (if userSettings.enable_bash_over_zsh or false then [ ./modules/bash ] else [ ./modules/zsh ])
    ++ (if userSettings.enable-ai-workflow then [ ./modules/ai-workflow ] else [])
    ++ (if userSettings.enable-neovim then [ ./modules/neovim/default.nix ] else [])
    ++ (if userSettings.import-extras or false then [ ./modules/extras ] else [])
    ++ (if userSettings.enable-smart-cd or false then [ ./modules/smart-cd ] else [])
    ++ (if userSettings.enable-agent-tracker or false then [ ./modules/agent-tracker ] else []);

  home.stateVersion = "23.11";

  programs.home-manager.enable = true;

  # Required for Home Manager to setup environment variables on non-NixOS Linux
  targets.genericLinux.enable = true;



  # You can customize the status bar position here
  programs.tmux.statusBarPosition = "bottom";

  programs.smart-cd.enable = userSettings.enable-smart-cd or false;
  programs.smart-cd.maxParents = userSettings.smart-cd-max-parents or 4;

  services.agent-tracker.enable = userSettings.enable-agent-tracker or false;

  home.packages = with pkgs; [
    fzf
    ripgrep
    bat
    pure-prompt
  ];
}
