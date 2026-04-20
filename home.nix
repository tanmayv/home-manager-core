{ pkgs, username, userSettings, ... }: {
  imports = [
    ./modules/zsh
    ./modules/tmux
    ./modules/hg.nix
    ./modules/test.nix
    ./modules/tmux-palette.nix
    ./modules/scripts
  ] ++ (if userSettings.enable-ai-workflow then [ ./modules/ai-workflow ] else [])
    ++ (if userSettings.enable-neovim then [ ./modules/neovim/default.nix ] else []);

  home.username = username;
  home.homeDirectory = "/usr/local/google/home/${username}";
  home.stateVersion = "23.11";

  programs.home-manager.enable = true;

  # Required for Home Manager to setup environment variables on non-NixOS Linux
  targets.genericLinux.enable = true;



  # You can customize the status bar position here
  programs.tmux.statusBarPosition = "bottom";

  home.packages = with pkgs; [
    fzf
    ripgrep
    bat
    pure-prompt
  ];
}
