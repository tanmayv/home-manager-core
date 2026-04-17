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
    initContent = ''
      # Basic Zsh config
      setopt histignorealldups sharehistory

      # Source shell history forwarder if it exists
      if [[ -f /etc/bash.bashrc.d/shell_history_forwarder.sh ]]; then
        source /etc/bash.bashrc.d/shell_history_forwarder.sh
      fi

      # Setup goog_prompt
      if [[ ! -d ~/zsh-async ]]; then
        git clone https://github.com/mafredri/zsh-async.git ~/zsh-async
      fi
      if [[ ! -f ~/goog_prompt.zsh ]]; then
        cp /google/data/ro/users/ju/jubi/goog_prompt.zsh ~/goog_prompt.zsh
      fi
      source ~/zsh-async/async.zsh
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
