{ pkgs, config, userSettings, lib, ... }:
let
  palette = import ../palette.nix;
  username = config.home.username;
  enableTmuxOnSsh = userSettings.enable-tmux-on-ssh or true;
  autoSwitchHg = userSettings.auto-switch-workspace-on-hgd or true;
  enableCdVerbose = userSettings.enable-cd-verbose or true;
  
  enableAiWorkflow = userSettings.enable-ai-workflow or false;
  aiFeatures = userSettings.ai_features or {
    enable_tmux_based_agent_comms = false;
  };
  enableAgentComms = enableAiWorkflow && (aiFeatures.enable_tmux_based_agent_comms or false);

  myAliases = {};
in
{
  options.programs.zsh = {
    prompt.pathShortener = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Zsh code to compute custom path for prompt. Should set `custom_path`.";
    };
    extraInit = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra zshrc content added by extensions.";
    };
  };

  config = {
    programs.bash = {
      enable = true;
      shellAliases = myAliases;
    };

  home.packages = with pkgs; [
    pure-prompt
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    dotDir = "${config.xdg.configHome}/zsh";
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    shellAliases = myAliases;

    initContent = ''
      ${lib.optionalString pkgs.stdenv.isDarwin ''
      # Nix
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
          . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi
      ''}

      zmodload zsh/nearcolor
      export COLORTERM=truecolor

      # Enable Bash-style sub-word deletion boundaries (stops at slashes, etc.)
      autoload -Uz select-word-style
      select-word-style bash


      # Accept autosuggestion with Ctrl+E
      bindkey '^E' autosuggest-accept

      # Move between next and previous commands
      bindkey '^P' up-line-or-history
      bindkey '^N' down-line-or-history

      # Basic Zsh config
      setopt histignorealldups sharehistory

      # Prompt initialization
      autoload -U promptinit; promptinit
      PURE_CMD_MAX_EXEC_TIME=2
      zstyle :prompt:pure:git:stash show no
      prompt pure

      # Customize Pure prompt: hide user/host and use custom path
      function customize_pure_prompt() {
        # Compute custom path
        local custom_path="%~"
        ${config.programs.zsh.prompt.pathShortener}
        
        # Recreate PROMPT with custom path
        PROMPT='%(12V.%F{$prompt_pure_colors[suspended_jobs]}%12v%f .)%F{''${prompt_pure_colors[path]}}'"$custom_path"'%f%(14V. %F{''${prompt_pure_git_branch_color}}%14v%(15V.%F{$prompt_pure_colors[git:dirty]}%15v.)%f.)%(16V. %F{$prompt_pure_colors[git:action]}%16v%f.)%(17V. %F{$prompt_pure_colors[git:arrow]}%17v%f.)%(18V. %F{$prompt_pure_colors[git:stash]}''${PURE_GIT_STASH_SYMBOL:-≡}%f.)%(19V. %F{$prompt_pure_colors[execution_time]}%19v%f.)'$'\n''%(20V.%F{$prompt_pure_colors[virtualenv]}%20v%f .)%(?.%F{${palette.color3}}.%F{$prompt_pure_colors[prompt:error]})❯%f '
      }
      autoload -Uz add-zsh-hook
      add-zsh-hook precmd customize_pure_prompt

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


      
      # Autostart tmux
      ${if enableTmuxOnSsh then ''
      if [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" ]] && [[ -z "$TMUX" ]]; then
        # Always prompt sessionizer to pick a workspace or default to a local path
        tmux-sessionizer
      fi
      '' else ""}

      # Extra init from extensions
      ${config.programs.zsh.extraInit}
    '';
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd cd" ];
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      auto_sync = false;
      search_mode = "fuzzy";
    };
  };
  };
}
