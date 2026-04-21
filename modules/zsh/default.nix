{ pkgs, config, username, userSettings, ... }:
let
  palette = import ../palette.nix;
  enableTmuxOnSsh = userSettings.enable-tmux-on-ssh or true;
  autoSwitchHg = userSettings.auto-switch-workspace-on-hgd or true;
  enableCdVerbose = userSettings.enable-cd-verbose or true;
  
  enableAiWorkflow = userSettings.enable-ai-workflow or false;
  aiFeatures = userSettings.ai_features or {
    enable_tmux_based_agent_comms = false;
  };
  enableAgentComms = enableAiWorkflow && (aiFeatures.enable_tmux_based_agent_comms or false);

  myAliases = {
    run-jetski-web = "/google/bin/releases/jetski-devs/jetski-web/run_jetski.par";
    hg = "chg";
    hgi = "fig_zoxide_cd";
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

      # Accept autosuggestion with Ctrl+E
      bindkey '^E' autosuggest-accept

      # Move between next and previous commands
      bindkey '^P' up-line-or-history
      bindkey '^N' down-line-or-history

      # Basic Zsh config
      setopt histignorealldups sharehistory

      # Source shell history forwarder if it exists
      if [[ -f /etc/bash.bashrc.d/shell_history_forwarder.sh ]]; then
        source /etc/bash.bashrc.d/shell_history_forwarder.sh
      fi

      # Google tool completions
      if [[ -f /etc/bash_completion.d/hgd ]]; then
        source /etc/bash_completion.d/hgd
      fi
      if [[ -f /etc/bash_completion.d/jjd ]]; then
        source /etc/bash_completion.d/jjd
      fi

      function _fast_workspace_cd() {
        local dest="$1"
        local original_arg="$2"

        # Check if we are currently in a CitC workspace
        if [[ "$PWD" == /google/src/cloud/$USER/*/google3* ]]; then
          local current_ws_root="''${PWD%%/google3*}/google3"
          
          # If the destination contains 'google3/', rewrite it to use our current workspace root
          if [[ "$dest" == */google3/* ]]; then
            local dest_relative="''${dest#*/google3/}"
            local target_path="$current_ws_root/$dest_relative"
            
            # Only rewrite if we used a zoxide jump (not if the user typed the exact absolute path)
            if [[ "$original_arg" != "$dest" ]]; then
              if [[ -d "$target_path" ]]; then
                # Automatically rewrite to current workspace and notify user
                local src_ws="''${dest#/google/src/cloud/$USER/}"
                src_ws="''${src_ws%%/*}"
                local current_ws="''${PWD#/google/src/cloud/$USER/}"
                current_ws="''${current_ws%%/*}"
                
                ${if enableCdVerbose then ''
                echo "Switching workspace from '$src_ws' -> '$current_ws'." >&2
                echo "Use 'builtin cd $dest' to jump to original workspace." >&2
                '' else ""}
                dest="$target_path"
              else
                local dest_ws="''${dest#/google/src/cloud/$USER/}"
                dest_ws="''${dest_ws%%/*}"
                echo -n "Directory not found in current workspace. Open in '$dest_ws' workspace? [y/N] "
                if read -q; then
                  echo
                  local current_ws="''${PWD#/google/src/cloud/$USER/}"
                  current_ws="''${current_ws%%/*}"
                  ${if enableCdVerbose then ''
                  echo "Switching workspace from '$current_ws' -> '$dest_ws'" >&2
                  '' else ""}
                  builtin cd "$dest"
                  return 0
                else
                  echo
                  return 1
                fi
              fi
            fi
          fi
        fi

        builtin cd "$dest"
      }

      function hgd() {
        local target_dir
        # Run hg hgd, capturing stdout and allowing stderr to print to terminal
        target_dir=$(hg hgd "$@")
        local local_status=$?
        
        if [[ $local_status -ne 0 || -z "$target_dir" ]]; then
          return $local_status
        fi
        
        # Change to the target directory
        builtin cd "$target_dir" || return $?

        ${if autoSwitchHg then ''
        # If in TMUX and we successfully switched to a workspace, sync the session
        if [[ -n "$TMUX" && "$PWD" == /google/src/cloud/$USER/* ]]; then
          local ws_part="''${PWD#/google/src/cloud/$USER/}"
          local ws_name="''${ws_part%%/*}"
          local ws_root="/google/src/cloud/$USER/$ws_name"
          
          local current_session=$(tmux display-message -p '#S' 2>/dev/null)
          if [[ "$current_session" != "$ws_name" && -d "$ws_root" ]]; then
            tmux-sessionizer "$ws_root"
          fi
        fi
        '' else ""}
      }

      function fig_zoxide_cd() {
        local dest
        dest=$(zoxide query -i -- "$@")
        if [[ -n "$dest" ]]; then
          _fast_workspace_cd "$dest" "$1"
        fi
      }

      function cd() {
        local print_only=false
        local interactive=false
        local codesearch=false
        local help=false
        local args=()

        while [[ "$#" -gt 0 ]]; do
          case "$1" in
            --print)
              print_only=true
              shift
              ;;
            -i)
              interactive=true
              shift
              ;;
            --cs)
              codesearch=true
              shift
              ;;
            -h|--help)
              help=true
              shift
              ;;
            *)
              args+=("$1")
              shift
              ;;
          esac
        done

        if [[ "$help" == "true" ]]; then
          echo "Usage: cd [options] [path|query]"
          echo "Options:"
          echo "  -i          Interactive mode (uses zoxide and fzf)"
          echo "  --cs        Search via CodeSearch"
          echo "  --print     Only print the target path, do not change directory"
          echo "  -h, --help  Show this help message"
          return 0
        fi

        if [[ "$codesearch" == "true" ]]; then
          cd-cs "''${args[@]}"
          if [[ -f /tmp/cd-cs-result ]]; then
            local target_dir
            target_dir=$(cat /tmp/cd-cs-result | tr -d '\n')
            rm -f /tmp/cd-cs-result
            if [[ -n "$target_dir" && -d "$target_dir" ]]; then
              if [[ "$print_only" == "true" ]]; then
                echo "$target_dir"
              else
                builtin cd "$target_dir"
              fi
            fi
          fi
          return 0
        fi

        if [[ "$interactive" == "true" ]]; then
          local selected
          selected=$(zoxide query -l | while read -r path; do
            local display_path="$path"
            if [[ "$path" == */google3/* ]]; then
              display_path="google3/''${path#*/google3/}"
            elif [[ "$path" == */google3 ]]; then
              display_path="google3"
            fi
            echo "$path|$display_path"
          done | awk -F'|' '!seen[$2]++' | ${pkgs.fzf}/bin/fzf --delimiter="|" --with-nth 2 --prompt="Interactive cd> ")

          if [[ -n "$selected" ]]; then
            local target_dir="''${selected%%|*}"
            if [[ "$print_only" == "true" ]]; then
              echo "$target_dir"
            else
              builtin cd "$target_dir"
            fi
          fi
          return 0
        fi

        local dest
        if [[ "''${#args[@]}" -eq 0 ]]; then
          dest="$HOME"
        elif [[ "''${#args[@]}" -eq 1 && "''${args[1]}" == "-" ]]; then
          dest="$OLDPWD"
        elif [[ "''${#args[@]}" -eq 1 && -d "''${args[1]}" ]]; then
          dest="''${args[1]}"
        else
          dest=$(zoxide query --exclude "$PWD" -- "''${args[@]}" 2>/dev/null)
          if [[ -z "$dest" ]]; then
            local prompt_codesearch=false
            if [[ "''${#args[@]}" -eq 1 ]]; then
              if ! builtin cd "''${args[1]}" 2>/dev/null; then
                prompt_codesearch=true
              fi
            else
              prompt_codesearch=true
            fi
            
            if [[ "$prompt_codesearch" == "true" ]]; then
              local search_done=false
              if [[ "${toString (userSettings.enable-auto-codesearch-with-cd or true)}" == "1" ]]; then
                echo -n "Search via CodeSearch? [y/N] "
                read response
                if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                  cd --cs "''${args[@]}"
                  search_done=true
                fi
              fi
              
              if [[ "$search_done" == "false" ]]; then
                echo "cd: no such file or directory: ''${args[@]}"
              fi
            fi
            return
          fi
        fi
        
        if [[ "$print_only" == "true" ]]; then
          echo "$dest"
        else
          _fast_workspace_cd "$dest" "''${args[1]}"
        fi
      }

      # Initialize Prompt
      autoload -U promptinit; promptinit

      # optionally define some options
      PURE_CMD_MAX_EXEC_TIME=2

      # turn on git stash status
      zstyle :prompt:pure:git:stash show no

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

      # Only check for updates in top-level shells (outside tmux)
      if [[ -z "$TMUX" ]]; then
        check-for-update
      fi

      # Autostart tmux only if not in Cider terminal
      ${if enableTmuxOnSsh then ''
      if [[ "$TERM_PROGRAM" != "cider" ]]; then
	if [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]] && [[ -z "$TMUX" ]]; then
	  current_dir=$(pwd)
	  workspace_root="/google/src/cloud/${username}"
	  # Check if current dir is a direct child of workspace_root
	  if [[ "$current_dir" == "$workspace_root"/* ]] && [[ "$(dirname "$current_dir")" == "$workspace_root" ]]; then
	    tmux-sessionizer "$current_dir"
	  else
	    # Always prompt sessionizer to pick a workspace or default to a local path
	    tmux-sessionizer
	  fi
	fi
      fi
      '' else ""}
    '';
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [];
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
