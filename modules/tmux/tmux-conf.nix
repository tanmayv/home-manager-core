{ pkgs, lib, config, ... }:
with lib;
let
  palette = import ../palette.nix;
  tmux-sessionizer = import ./tmux-sessionizer.nix { inherit pkgs; maxDirLength = config.programs.tmux.sessionizerMaxDirLength; };
  hg-age = import ./hg-age.nix { inherit pkgs; };
  hg-cl = import ./hg-cl.nix { inherit pkgs; };
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

  tmux-agent-list-formatter = pkgs.writeScriptBin "tmux-agent-list-formatter" ''
    #!${pkgs.python3}/bin/python3
    import sys
    import subprocess

    width = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    available = width - 20

    # Get all panes with @agent_name
    try:
        output = subprocess.check_output([
            "tmux", "list-panes", "-a", "-F", 
            "#{session_name}|#{window_index}|#{pane_index}|#{@agent_name}"
        ]).decode("utf-8")
    except:
        sys.exit(0)

    agents = []
    for line in output.splitlines():
        parts = line.split("|")
        if len(parts) == 4 and parts[3].strip():
            agents.append({
                "session": parts[0],
                "window": parts[1],
                "pane": parts[2],
                "name": parts[3].strip()
            })

    if not agents:
        sys.exit(0)

    formatted = []
    for a in agents:
        # Range format: agent:SESSION:WINDOW:PANE
        target = f"{a['session']}:{a['window']}.{a['pane']}"
        range_arg = f"agent:{a['session']}:{a['window']}:{a['pane']}"
        formatted.append(f"#[range=user|{range_arg}]{a['name']}#[norange]")

    res = ' · '.join(formatted)
    print(res)
  '';

  tmux-status-refresh = pkgs.writeScriptBin "tmux-status-refresh" ''
    #!${pkgs.bash}/bin/bash
    # Dynamically set status lines (1, 2, or 3) and set global flags
    num_sessions=$(tmux list-sessions | wc -l)
    num_agents=$(tmux list-panes -a -F "#{@agent_name}" | grep -v "^$" | wc -l)
    
    if [ "$num_sessions" -gt 1 ]; then
        tmux set-option -g @is_multi_session 1
    else
        tmux set-option -g @is_multi_session 0
    fi

    if [ "$num_agents" -gt 0 ]; then
        tmux set-option -g @has_agents 1
    else
        tmux set-option -g @has_agents 0
    fi

    lines=1
    if [ "$num_sessions" -gt 1 ]; then
        lines=$((lines + 1))
    fi
    if [ "$num_agents" -gt 0 ]; then
        lines=$((lines + 1))
    fi
    
    current_status=$(tmux show-options -g status | cut -d' ' -f2)
    
    if [ "$lines" -eq 1 ]; then
        target="on"
    else
        target="$lines"
    fi
    
    if [ "$current_status" != "$target" ]; then
        tmux set -g status "$target"
    fi
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
      tmux-agent-list-formatter
      tmux-status-refresh
      hg-age
      hg-cl
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
        
        # Disable application-driven renaming, but keep tmux automatic renaming
        set-window-option -g allow-rename off
        set-window-option -g automatic-rename on
        set-option -g set-titles off
        
        # Pane border and title configuration
        set -g pane-border-status top
        set -g pane-border-format "#[fg=${palette.color8}]─(#[fg=${palette.color5}] #D #[fg=${palette.color8}]| #[fg=${palette.color4}]#{?@agent_name,#{@agent_name},no-name} #[fg=${palette.color8}]| #[fg=${palette.color2}]#T #[fg=${palette.color8}])─"
        set -g pane-border-style "fg=${palette.color8}"
        set -g pane-active-border-style "fg=${palette.color4}"
        
        # Tmux Sessionizer integration
        bind-key C-t display-popup -w 95% -h 80% -E "tmux-sessionizer"
        
        # Tmux Command Palette
        bind-key C-p display-popup -T "Command Palette" -w 90% -h 70% -E "tmux-palette"
        
        # Status Bar Position
        set -g status-position ${config.programs.tmux.statusBarPosition}
        


        # tmux-dotbar Tokyo Night theme configuration
        set -g status-justify "absolute-centre"
        set -g status-left-length 60
        set -g status-left "#{?client_prefix,#[bg=${palette.color2} fg=${palette.background} bold],#[fg=${palette.color4} bold]} #S #[default]"
        set -g status-right-length 120
        set -g status-right "#[fg=${palette.color5}]#{?#{==:#{status},2},,#(hg-cl) }#[fg=default,nobold]#{?#{==:#{status},2},,#(hg-age) }#[range=user|palette]#[fg=${palette.color6}] [CMDS] #[norange]"
        set -g window-status-format " #W "
        set -g window-status-current-format "#[bg=default,fg=${palette.color3},bold] #W #[fg=${palette.color4},bg=default]#{?window_zoomed_flag,󰊓,}#[fg=default,bg=default]"
        set -g window-status-separator " • "
        set -g status-style "bg=default,fg=${palette.color8}"
        set -g window-status-style "bg=default,fg=${palette.color8}"

        # Smart pane switching with awareness of Vim splits.
        is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
            | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf|hx|lazygit)(diff)?$'"
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
        set -g status-interval 5
        set -g detach-on-destroy off

        # Dynamic status line management based on session and agent count
        set-hook -g session-created 'run-shell "tmux-status-refresh"'
        set-hook -g session-closed 'run-shell "tmux-status-refresh"'
        set-hook -g pane-exited 'run-shell "tmux-status-refresh"'

        # Run the check immediately on config load
        run-shell "tmux-status-refresh"

        # Content of the second status line (Sessions if > 1, else Agents if any)
        set -g status-format[1] "#[align=left,fg=${palette.color4},bold]#{?#{==:#{@is_multi_session},1}, Active Sessions: #[fg=${palette.foreground},nobold]#(tmux list-sessions -F \"##{session_created}|##{session_name}|##{session_id}\" | tmux-session-list-formatter 150 \"#S\"), Active Agents: #[fg=${palette.foreground},nobold]#(tmux-agent-list-formatter \"#{client_width}\")}#[align=right,fg=${palette.color5}]#(hg-cl) #[fg=default,nobold]#(hg-age) "
        
        # Content of the third status line (Agents if sessions > 1 and agents exist)
        set -g status-format[2] "#[align=left,fg=${palette.color4},bold] Active Agents: #[fg=${palette.foreground},nobold]#(tmux-agent-list-formatter \"#{client_width}\")"

        # Global mouse binding to handle status bar clicks
        bind-key -n MouseDown1Status if-shell -F '#{==:#{mouse_status_range},palette}' \
            { display-popup -w 90% -h 70% -E "tmux-palette" } \
            { if-shell -F '#{==:#{mouse_status_range},clinfo}' \
                { run-shell "hg-cl --copy" } \
                { if-shell -F '#{==:#{mouse_status_range},session}' \
                    { switch-client -t = } \
                    { if-shell -F '#{m:agent:*,#{mouse_status_range}}' \
                        { 
                            # Extract SESSION:WINDOW:PANE from agent:SESSION:WINDOW:PANE
                            target="#{s/agent://:mouse_status_range}"
                            # target is now SESSION:WINDOW:PANE, but wait, 
                            # tmux switch-client -t expects target-pane.
                            # The s/// might be tricky with multiple colons.
                            # Let's use a run-shell helper if it's too complex for native format.
                            run-shell "tmux_target=$(echo '#{mouse_status_range}' | cut -d: -f2-4 | tr ':' '.'); \
                                       session_name=$(echo \$tmux_target | cut -d. -f1); \
                                       tmux switch-client -t \$session_name; \
                                       tmux select-window -t \$tmux_target; \
                                       tmux select-pane -t \$tmux_target"
                        } \
                        { select-window -t = } \
                    } \
                } \
            }

        # Right-click menu for hg-age (ageinfo range) or hg-cl (clinfo range)
        bind-key -n MouseDown3Status \
            if-shell -F '#{==:#{mouse_status_range},ageinfo}' \
                { display-menu -T "#[align=centre]Repository Sync" -t = -x M -y W \
                    "Sync Current" s { display-popup -T "Syncing Current Workspace" -w 80% -h 60% -E "hg sync && read" } \
                    "Sync All" a { display-popup -T "Syncing All Workspaces" -w 80% -h 60% -E "for d in /google/src/cloud/$USER/*; do if [ -d \"$d/google3\" ]; then echo \"Syncing $d...\"; (cd \"$d\" && hg sync); fi; done; echo \"Finished syncing all workspaces.\"; read" } \
                } \
                { if-shell -F '#{==:#{mouse_status_range},clinfo}' \
                    { display-menu -T "#[align=centre]CL Management" -t = -x M -y W \
                        "Copy CL Number" c { run-shell "hg-cl --copy" } \
                        "Switch CL" s { display-popup -T "Switch CL" -w 80% -h 60% -E "hg pickcheckout" } \
                        "Amend" a { display-popup -T "Amend CL" -w 95% -h 80% -E "hg amend -i" } \
                        "Commit" C { display-popup -T "Commit CL" -w 95% -h 80% -E "hg commit -i" } \
                    } \
                    { select-window -t = } \
                }

        # Enhanced right-click menu for session list on the left
        bind-key -T root MouseDown3StatusLeft display-menu -T "#[align=centre]#{session_name}" -t = -x M -y W Next n { switch-client -n } Previous p { switch-client -p } "" Renumber N { move-window -r } Rename n { command-prompt -I "#S" { rename-session "%%" } } "" "New Session" s { new-session } "New Window" w { new-window } "" "Kill Session" X { kill-session }
      '';
    };
  };
}
