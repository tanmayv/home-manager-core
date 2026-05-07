{ pkgs, config, userSettings, ... }:
let
  palette = import ../palette.nix;
  username = config.home.username;
  enableTmuxOnSsh = userSettings.enable-tmux-on-ssh or true;
  autoSwitchHg = userSettings.auto-switch-workspace-on-hgd or true;
  enableCdVerbose = userSettings.enable-cd-verbose or true;
  
in
{
  imports = [
  ];

  programs.bash = {
    enable = true;
    shellAliases = {};

    initExtra = ''
      export COLORTERM=truecolor
      # Basic Bash config
      HISTCONTROL=ignoredups:erasedups
      shopt -s histappend
      HISTSIZE=10000
      HISTFILESIZE=20000

      # Fix SSH agent socket if it dies within long-running tmux sessions
      function fixup_ssh_auth_sock() {
        if [[ -n "''${SSH_AUTH_SOCK}" && ! -e "''${SSH_AUTH_SOCK}" ]]; then
          local new_sock=$(ls -t /tmp/ssh-*/agent.* 2>/dev/null | head -n 1)
          if [[ -n "''${new_sock}" ]]; then
            export SSH_AUTH_SOCK="''${new_sock}"
          fi
        fi
      }

      # Run fixup on every command if SSH_AUTH_SOCK is set
      if [[ -n "''${SSH_AUTH_SOCK}" ]]; then
        PROMPT_COMMAND="fixup_ssh_auth_sock; $PROMPT_COMMAND"
      fi

      # Only check for updates in top-level shells (outside tmux)
      if [[ -z "$TMUX" ]]; then
        check-for-update
      fi
      
      # Autostart tmux
      ${if enableTmuxOnSsh then ''
      if [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]] && [[ -z "$TMUX" ]]; then
        # Always prompt sessionizer to pick a workspace or default to a local path
        tmux-sessionizer
      fi
      '' else ""}
    '';
    '';
  };

  programs.zoxide = {
    enable = true;
    enableBashIntegration = true;
    options = [];
  };

  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      auto_sync = false;
      search_mode = "fuzzy";
    };
  };
}
