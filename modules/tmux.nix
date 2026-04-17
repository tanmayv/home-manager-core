{ pkgs, lib, config, ... }:
with lib;
let
  tmux-sessionizer = import ./tmux-sessionizer.nix { inherit pkgs; maxDirLength = config.programs.tmux.sessionizerMaxDirLength; };
in
{
  options.programs.tmux = {
    statusBarPosition = mkOption {
      type = types.str;
      default = "bottom";
      description = "Set status bar position";
    };
    sessionizerMaxDirLength = mkOption {
      type = types.int;
      default = 16;
      description = "Maximum directory name length to include in tmux-sessionizer search";
    };
  };

  config = {
    home.packages = [
      tmux-sessionizer
    ];

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
        
        # Tmux Sessionizer integration
        bind-key C-t display-popup -w 95% -h 80% -E "tmux-sessionizer"
        
        # Status Bar Position
        set -g status-position ${config.programs.tmux.statusBarPosition}
        
        # UI/Pane Border adjustments
        set-option -g pane-border-status top
        set -g pane-border-lines double
        set -g pane-border-format " [#{pane_index}] #{pane_title} "
        bind . command-prompt -p "(rename-pane)" -I "#T" "select-pane -T '%%'"

        # tmux-dotbar Tokyo Night theme configuration
        set -g status-justify "absolute-centre"
        set -g status-left "#[bg=#0B0E14,fg=#565B66]#{?client_prefix,, #S }#[bg=#95E6CB,fg=#0B0E14,bold]#{?client_prefix, #S ,}#[bg=#0B0E14,fg=#565B66]"
        set -g status-right ""
        set -g window-status-format " #W "
        set -g window-status-current-format "#[bg=#0B0E14,fg=#BFBDB6,bold] #W #[fg=#39BAE6,bg=#0B0E14]#{?window_zoomed_flag,󰊓,}#[fg=#0B0E14,bg=default]"
        set -g window-status-separator " • "
        set -g status-style "bg=#0B0E14,fg=#475266"
        set -g window-status-style "bg=#0B0E14,fg=#475266"
      '';
    };
  };
}
