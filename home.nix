{ pkgs, username, ... }: {
  imports = [
    ./modules/zsh.nix
    ./modules/tmux.nix
  ];

  home.username = username;
  home.homeDirectory = "/usr/local/google/home/${username}";
  home.stateVersion = "23.11";

  programs.home-manager.enable = true;

  # You can customize the status bar position here
  programs.tmux.statusBarPosition = "bottom";

  home.packages = with pkgs; [
    fzf
    ripgrep
  ];
}
