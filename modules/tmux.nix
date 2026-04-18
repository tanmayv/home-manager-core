{ pkgs, lib, config, ... }:
with lib;
let
  palette = import ./palette.nix;
  tmux-sessionizer = import ./tmux-sessionizer.nix { inherit pkgs; maxDirLength = config.programs.tmux.sessionizerMaxDirLength; };
  tmux-session-list-formatter = pkgs.writeScriptBin "tmux-session-list-formatter" ''
    #!${pkgs.python3}/bin/python3
    import sys

    if len(sys.argv) < 3:
        sys.exit(1)

    width = int(sys.argv[1])
    current = sys.argv[2]
    available = width - 10 # Margin for right buttons

    lines = sys.stdin.read().splitlines()

    sessions = []
    for line in lines:
        parts = line.split("|")
        if len(parts) == 3:
            sessions.append({"created": int(parts[0]), "name": parts[1], "id": parts[2]})

    # Sort by timestamp (oldest first)
    sessions.sort(key=lambda s: s["created"])

    # Remove sessions until it fits based on visible length (names)
    truncated = False
    while len(' · '.join(s["name"] for s in sessions)) > available and len(sessions) > 1:
        sessions.pop() # Remove from the end (newest)
        truncated = True

    formatted = []
    for s in sessions:
        name = s["name"]
        sid = s["id"]
        display_name = f"#[bold]{name}#[nobold]" if name == current else name
        formatted.append(f"#[range=session|{sid}]{display_name}#[norange]")

    output = ' · '.join(formatted)

    if truncated:
        output += " · ..."

    print(output)
  '';
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
      tmux-session-list-formatter
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
        


        # tmux-dotbar Tokyo Night theme configuration
        set -g status-justify "absolute-centre"
        set -g status-left-length 20
        set -g status-left "#[bg=${palette.color2},fg=${palette.background},bold]#{?client_prefix, PREFIX ,}#[bg=default,fg=${palette.foreground},bold] #S #[default]"
        set -g status-right "#[range=user|palette] [CMDS] #[norange]"
        set -g window-status-format " #W "
        set -g window-status-current-format "#[bg=default,fg=${palette.color3},bold] #W #[fg=${palette.color4},bg=default]#{?window_zoomed_flag,󰊓,}#[fg=default,bg=default]"
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



        # Set default status bar to 1 line
        set -g status on
        set -g detach-on-destroy off

        # Dynamic second status line based on session count
        set-hook -g session-created 'run-shell "if [ $(tmux list-sessions | wc -l) -gt 1 ]; then tmux set -g status 2; else tmux set -g status on; fi"'
        set-hook -g session-closed 'run-shell "if [ $(tmux list-sessions | wc -l) -gt 1 ]; then tmux set -g status 2; else tmux set -g status on; fi"'

        # Content of the second status line
        set -g status-format[1] "#[align=centre,bg=default,fg=${palette.foreground}]#(tmux list-sessions -F \"##{session_created}|##{session_name}|##{session_id}\" | tmux-session-list-formatter \"#{client_width}\" \"#S\")"

        # Global mouse binding to handle session clicks
        bind-key -n MouseDown1Status if-shell -F '#{==:#{mouse_status_range},session}' "switch-client" "select-window -t ="

        # Mouse binding for [CMDS] button in status-right
        bind-key -n MouseDown1StatusRight if-shell -F '#{==:#{mouse_status_range},palette}' "display-popup -w 90% -h 70% -E 'tmux-palette'"

        # Enhanced right-click menu for session list on the left
        bind-key -T root MouseDown3StatusLeft display-menu -T "#[align=centre]#{session_name}" -t = -x M -y W Next n { switch-client -n } Previous p { switch-client -p } "" Renumber N { move-window -r } Rename n { command-prompt -I "#S" { rename-session "%%" } } "" "New Session" s { new-session } "New Window" w { new-window } "" "Kill Session" X { kill-session }
      '';
    };
  };
}
