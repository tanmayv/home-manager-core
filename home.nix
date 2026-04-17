{ pkgs, username, ... }: {
  home.username = username;
  home.homeDirectory = "/usr/local/google/home/${username}";
  home.stateVersion = "23.11";

  programs.home-manager.enable = true;

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = {
      ll = "ls -l";
      la = "ls -a";
    };
    initExtra = ''
      # Basic Zsh config
      setopt histignorealldups sharehistory
    '';
  };

  programs.tmux = {
    enable = true;
    shortcut = "b";
    baseIndex = 1;
    newSession = true;
    escapeTime = 0;
    historyLimit = 10000;
    keyMode = "vi";
    terminal = "screen-256color";
    extraConfig = ''
      set -g mouse on
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"
    '';
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      auto_sync = false;
      search_mode = "fuzzy";
    };
  };

  home.packages = with pkgs; [
    fzf
    ripgrep
  ];
}
