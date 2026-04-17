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

      # Google tool completions
      for completion_file in /etc/bash_completion.d/{hgd,jjd,p4,g4d}; do
        if [[ -f "$completion_file" ]]; then
          source "$completion_file"
        fi
      done

      # Custom path logic for CitC workspaces
      function set_citc_hash() {
        if [[ "$PWD" == /google/src/cloud/$USER/* ]]; then
          local ws="''${PWD#/google/src/cloud/$USER/}"
          ws="''${ws%%/*}"
          hash -d "$ws"="/google/src/cloud/$USER/$ws"
        fi
      }
      autoload -Uz add-zsh-hook
      add-zsh-hook chpwd set_citc_hash
      set_citc_hash

      # Setup pure prompt
      # Pure prompt performance optimizations for large Google repos
      PURE_GIT_PULL=0
      PURE_GIT_UNTRACKED_DIRTY=0
      PURE_CMD_MAX_EXEC_TIME=1
      autoload -U promptinit; promptinit
      prompt pure

      # Make user and host visible on dark themes (default is dark grey 242)
      zstyle ':prompt:pure:user' color cyan
      zstyle ':prompt:pure:host' color white

      # gcert wrapper to ensure environment variables are up-to-date in tmux
      function gcert() {
        if [[ -n $TMUX ]]; then
          eval $(tmux show-environment -s)
        fi
        command gcert "$@"
      }

      # Fix SSH agent socket if it dies within long-running tmux sessions
      function fixup_ssh_auth_sock() {
        if [[ -n "''${SSH_AUTH_SOCK}" && ! -e "''${SSH_AUTH_SOCK}" ]]; then
          local new_sock=$(echo /tmp/ssh-*/agent.*(=UNomY1) 2>/dev/null | head -n 1)
          if [[ -n "''${new_sock}" ]]; then
            export SSH_AUTH_SOCK="''${new_sock}"
          fi
        fi
      }
      
      if [[ -n "''${SSH_AUTH_SOCK}" ]]; then
        autoload -Uz add-zsh-hook
        add-zsh-hook preexec fixup_ssh_auth_sock
      fi

      # Auto-attach to tmux on SSH login
      if [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]] && [[ -z "$TMUX" ]]; then
        if tmux ls >/dev/null 2>&1; then
          exec tmux attach-session
        else
          exec tmux new-session -s default
        fi
      fi
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
