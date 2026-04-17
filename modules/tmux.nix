{ pkgs, lib, config, ... }:
with lib;
let
  palette = import ./palette.nix;
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
      default = 25;
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
      newSession = false;
      escapeTime = 0;
      historyLimit = 10000;
      keyMode = "vi";
      terminal = "screen-256color";
      extraConfig = ''
        set -g mouse on
        bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"
        set -ga terminal-overrides ",*256col*:Tc"
        
        # Tmux Sessionizer integration
        bind-key C-t display-popup -w 95% -h 80% -E "tmux-sessionizer"
        
        # Tmux Command Palette
        bind-key C-p display-popup -T "Command Palette" -w 90% -h 70% -E "tmux-palette"
        
        # Status Bar Position
        set -g status-position ${config.programs.tmux.statusBarPosition}
        
        # UI/Pane Border adjustments
        set-option -g pane-border-status top
        set -g pane-border-lines double
        set -g pane-border-format " [#{pane_index}] #{pane_title} "
        bind . command-prompt -p "(rename-pane)" -I "#T" "select-pane -T '%%'"

        # tmux-dotbar Tokyo Night theme configuration
        set -g status-justify "absolute-centre"
        set -g status-left-length 20
        set -g status-left "#[bg=default,fg=${palette.color8}]#{?client_prefix,, #S }#[bg=${palette.color2},fg=${palette.background},bold]#{?client_prefix, #S ,}#[bg=default,fg=${palette.color8}]"
        set -g status-right ""
        set -g window-status-format " #W "
        set -g window-status-current-format "#[bg=default,fg=${palette.foreground},bold] #W #[fg=${palette.color4},bg=default]#{?window_zoomed_flag,󰊓,}#[fg=default,bg=default]"
        set -g window-status-separator " • "
        set -g status-style "bg=default,fg=${palette.color8}"
        set -g window-status-style "bg=default,fg=${palette.color8}"

        # Smart pane switching with awareness of Vim splits.
        is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
            | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?$'"
        bind-key -n 'C-h' if-shell "$is_vim" 'send-keys C-h'  'select-pane -L'
        bind-key -n 'C-j' if-shell "$is_vim" 'send-keys C-j'  'select-pane -D'
        bind-key -n 'C-k' if-shell "$is_vim" 'send-keys C-k'  'select-pane -U'
        bind-key -n 'C-l' if-shell "$is_vim" 'send-keys C-l'  'select-pane -R'

        bind-key -T copy-mode-vi 'C-h' select-pane -L
        bind-key -T copy-mode-vi 'C-j' select-pane -D
        bind-key -T copy-mode-vi 'C-k' select-pane -U
        bind-key -T copy-mode-vi 'C-l' select-pane -R
      '';
    };
  };
}
