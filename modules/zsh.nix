{ pkgs, config, ... }:
let
  myAliases = {
    ll = "ls -l";
    la = "ls -a";
    jetski-cli = "/google/bin/releases/jetski-devs/tools/cli";
  };
in
{
  programs.bash = {
    enable = true;
    shellAliases = myAliases;
  };

  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = myAliases;

    plugins = [
      {
        name = "zsh-async";
        file = "async.zsh";
        src = pkgs.fetchFromGitHub {
          owner = "mafredri";
          repo = "zsh-async";
          rev = "v1.8.6";
          sha256 = "1lnhw9h833n5n1yp4n456sbg0ivyrdnbmb04k47sf4l0c6ygvkr6";
        };
      }
    ];

    initContent = ''
      # Basic Zsh config
      setopt histignorealldups sharehistory

      # Source shell history forwarder if it exists
      if [[ -f /etc/bash.bashrc.d/shell_history_forwarder.sh ]]; then
        source /etc/bash.bashrc.d/shell_history_forwarder.sh
      fi

      # Setup goog_prompt
      if [[ ! -f ~/goog_prompt.zsh ]]; then
        cp /google/data/ro/users/ju/jubi/goog_prompt.zsh ~/goog_prompt.zsh
      fi
      source ~/goog_prompt.zsh
    '';
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [
      "--cmd cd"
    ];
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      auto_sync = false;
      search_mode = "fuzzy";
    };
  };
}
