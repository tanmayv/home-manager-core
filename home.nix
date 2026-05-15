{ pkgs, lib, userSettings ? {}, inputs, ... }:
{
  imports = [
    ./modules/tmux
    ./modules/tmux-palette.nix
    ./modules/terminal
    ./modules/scripts
    ./modules/agent-tracker
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
    ripgrep
    bat
    pure-prompt
  ];
}
