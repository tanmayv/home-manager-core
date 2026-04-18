{ pkgs, config, username, ... }:
let
  palette = import ./palette.nix;
  myAliases = {
    ll = "ls -l";
    la = "ls -a";
    jetski-cli = "/google/bin/releases/jetski-devs/tools/cli";
    start-jetski-web = "/google/bin/releases/jetski-devs/jetski-web/run_jetski.par";
  };
in
{
  programs.bash = {
    enable = true;
    shellAliases = myAliases;
  };

  home.packages = with pkgs; [
    pure-prompt
  ];

  programs.zsh = {
    enable = true;
    dotDir = "${config.xdg.configHome}/zsh";
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = myAliases;

    initContent = ''
      zmodload zsh/nearcolor
      export COLORTERM=truecolor


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
      # function set_citc_hash() {
      #   if [[ "$PWD" == /google/src/cloud/$USER/* ]]; then
      #     local ws="''${PWD#/google/src/cloud/$USER/}"
      #     ws="''${ws%%/*}"
      #     hash -d "$ws"="/google/src/cloud/$USER/$ws"
      #   fi
      # }
      # autoload -Uz add-zsh-hook
      # add-zsh-hook chpwd set_citc_hash
      # set_citc_hash

      # Initialize Prompt
      autoload -U promptinit; promptinit

      # optionally define some options
      PURE_CMD_MAX_EXEC_TIME=10

      # turn on git stash status
      zstyle :prompt:pure:git:stash show yes

prompt_pure_username=""
prompt_pure_host=""
      prompt pure

      # Customize Pure prompt: hide user/host and use custom workspace path
      function customize_pure_prompt() {
        prompt_pure_state[username]=""
        
        # Compute custom path
        local custom_path="%~"
        if [[ "$PWD" == /google/src/cloud/$USER/* ]]; then
          local ws="''${PWD#/google/src/cloud/$USER/}"
          local rest="''${ws#*/}"
          ws="''${ws%%/*}"
          if [[ "$rest" == "$ws" ]]; then
            custom_path="%F{${palette.color5}}($ws)%f"
          else
            custom_path="%F{${palette.color5}}($ws)%f · $rest"
          fi
        fi
        
        # Recreate PROMPT with custom path
        PROMPT='%(12V.%F{$prompt_pure_colors[suspended_jobs]}%12v%f .)%(13V.''${prompt_pure_state[username]} .)%F{''${prompt_pure_colors[path]}}'"$custom_path"'%f%(14V. %F{''${prompt_pure_git_branch_color}}%14v%(15V.%F{$prompt_pure_colors[git:dirty]}%15v.)%f.)%(16V. %F{$prompt_pure_colors[git:action]}%16v%f.)%(17V. %F{$prompt_pure_colors[git:arrow]}%17v%f.)%(18V. %F{$prompt_pure_colors[git:stash]}''${PURE_GIT_STASH_SYMBOL:-≡}%f.)%(19V. %F{$prompt_pure_colors[execution_time]}%19v%f.)''${prompt_newline}%(20V.%F{$prompt_pure_colors[virtualenv]}%20v%f .)%(?.%F{${palette.color3}}.%F{$prompt_pure_colors[prompt:error]})''${prompt_pure_state[prompt]}%f '
      }
      autoload -Uz add-zsh-hook
      add-zsh-hook precmd customize_pure_prompt

      # gcert wrapper to ensure environment variables are up-to-date in tmux
      function gcert() {
        if [[ -n $TMUX ]]; then
          eval $(tmux show-environment -s)
        fi
        command gcert "$@" && fuse_fix
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

      # Autostart tmux only if not in Cider terminal
      if [[ "$TERM_PROGRAM" != "cider" ]]; then
	if [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]] && [[ -z "$TMUX" ]]; then
	  current_dir=$(pwd)
	  workspace_root="/google/src/cloud/${username}"
	  # Check if current dir is a direct child of workspace_root
	  if [[ "$current_dir" == "$workspace_root"/* ]] && [[ "$(dirname "$current_dir")" == "$workspace_root" ]]; then
	    exec tmux-sessionizer "$current_dir"
	  else
	    if tmux ls >/dev/null 2>&1; then
	      exec tmux attach-session
	    else
	      exec tmux new-session -s default
	    fi
	  fi
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
