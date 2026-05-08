{ pkgs, lib, config, userSettings, ... }:
with lib;
let
  palette = import ../palette.nix;
  
  # Check if AI features are enabled
  enableAiWorkflow = userSettings.enable-ai-workflow or false;
  aiFeatures = userSettings.ai_features or {
    enable_ai_ssa_creator_skill = false;
    enable_tmux_based_agent_comms = false;
    enable_agent_knowledge = false;
  };
  enableAgentComms = enableAiWorkflow && (aiFeatures.enable_tmux_based_agent_comms or false);

  tmux-sessionizer = import ./tmux-sessionizer.nix {
    inherit pkgs lib;
    maxDirLength = config.programs.tmux.sessionizerMaxDirLength;
    searchPaths = config.programs.tmux.sessionizerSearchPaths;
    displayReplacements = config.programs.tmux.sessionizerDisplayReplacements;
  };
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
        if name == current:
            display_name = f"#[fg=${palette.color3},bold]{name}#[fg=${palette.color8},nobold]"
        else:
            display_name = name
        formatted.append(f"#[range=session|{sid}]{display_name}#[norange]")

    output = ' · '.join(formatted)

    if truncated:
        output += " · ..."

    print(output)
  '';



  tmux-status-refresh = pkgs.writeScriptBin "tmux-status-refresh" ''
    #!${pkgs.bash}/bin/bash
    # Dynamically set status lines and formats
    
    # Core row 1 (Active Sessions)
    SESSIONS_PART="#[align=left,fg=${palette.color4},bold] Active Sessions: #[fg=${palette.color8},nobold]#(tmux list-sessions -F \"##{session_created}|##{session_name}|##{session_id}\" | tmux-session-list-formatter 150 \"#S\")"
    
    # Row 0 right part from extensions
    ROW0_RIGHT="${concatStringsSep " " config.programs.tmux.statusBar.row0.right}"
    
    # Calculate how many extra lines we need
    declare -A lines
    line_idx=1
    
    # Check active sessions condition (show if > 1)
    num_sessions=$(tmux list-sessions | wc -l)
    if [ "$num_sessions" -gt 1 ]; then
        lines[$line_idx]="$SESSIONS_PART"
        line_idx=$((line_idx + 1))
    fi
    
    # Process extra lines from extensions
    ${concatStringsSep "\n" (map (line: ''
      if ${line.condition}; then
        lines[$line_idx]="#[align=left]${line.command}"
        line_idx=$((line_idx + 1))
      fi
    '') config.programs.tmux.statusBar.extraLines)}
    
    # Set status lines
    total_lines=$((line_idx - 1))
    
    if [ "$total_lines" -eq 0 ]; then
        tmux set -g status on
    else
        tmux set -g status "$((total_lines + 1))"
        for i in "''${!lines[@]}"; do
            tmux set -g status-format[$i] "''${lines[$i]}"
        done
    fi
    
    # Update row 0 right if needed (handled in static config usually, but could be dynamic)
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
    sessionizerSearchPaths = mkOption {
      type = types.listOf types.str;
      default = [ "~" ];
      description = "Paths to search for sessions in tmux-sessionizer.";
    };
    sessionizerDisplayReplacements = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Map of path prefixes to display names in fzf (e.g., { \"/path/to/dir\" = \"[TAG]\"; }).";
    };
    statusBar = {
      row0 = {
        right = mkOption {
          type = types.listOf types.str;
          default = [];
          description = "Content to add to the right of row 0";
        };
      };
      extraLines = mkOption {
        type = types.listOf (types.submodule {
          options = {
            name = mkOption { type = types.str; };
            command = mkOption { type = types.str; };
            condition = mkOption { type = types.str; default = "true"; };
          };
        });
        default = [];
        description = "Extra status lines";
      };
    };
  };

  config = {
    home.packages = [
      tmux-sessionizer
      tmux-session-list-formatter
      tmux-status-refresh
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
        set -g pane-border-status bottom
        set -g pane-border-format "#[fg=${palette.color8}]─(#[fg=${palette.color5}] #D #[fg=${palette.color8}]| ${if enableAgentComms then "#[fg=${palette.color4}]#{?@agent_name,#{@agent_name},no-name} #[fg=${palette.color8}]| " else ""}#[fg=${palette.color2}]#T #[fg=${palette.color8}])─"
        set -g pane-border-style "fg=${palette.color8}"
        set -g pane-active-border-style "fg=${palette.color4}"
        
        # Tmux Sessionizer integration
        bind-key C-t display-popup -w 95% -h 80% -E "tmux-sessionizer"
        
        # Tmux Command Palette
        bind-key C-p display-popup -T "Command Palette" -w 90% -h 70% -E "tmux-palette #{pane_id}"
        
        # Status Bar Position
        set -g status-position ${config.programs.tmux.statusBarPosition}
        


        # tmux-dotbar Tokyo Night theme configuration
        set -g status-justify "absolute-centre"
        set -g status-left-length 60
        set -g status-left "#{?client_prefix,#[bg=${palette.color2} fg=${palette.background} bold],#[fg=${palette.color4} bold]} #S #[default]"
        set -g status-right-length 120
        set -g status-right "#{?#{!=:#{status},on},,${concatStringsSep " " config.programs.tmux.statusBar.row0.right} }#[range=user|palette]#[fg=${palette.color6}] [CMDS] #[norange]"
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

        # Global mouse binding to handle status bar clicks
        bind-key -n MouseDown1Status if-shell -F '#{==:#{mouse_status_range},palette}' \
            { display-popup -w 90% -h 70% -E "tmux-palette #{pane_id}" } \
            { if-shell -F '#{==:#{mouse_status_range},session}' \
                { switch-client -t = } \
                { if-shell -F '#{m:agent:*,#{mouse_status_range}}' \
                    { 
                        # Extract pane_id from agent:pane_id
                        run-shell "echo 'range=#{mouse_status_range}' >> /tmp/click-debug.log; \
                                   target_id=$(echo '#{mouse_status_range}' | cut -d: -f2); \
                                   if tmux list-panes -a -F '##{pane_id}' | grep -q \"^\$target_id\$\"; then \
                                       tmux switch-client -t \"\$target_id\"; \
                                       tmux select-pane -t \"\$target_id\"; \
                                   else \
                                       agent-tracker-ctl unregister --pane \"\$target_id\"; \
                                       tmux display-message \"Agent pane not found, entry removed\"; \
                                   fi"
                    } \
                    { select-window -t = } \
                } \
            }

        # Enhanced right-click menu for session list on the left
        bind-key -T root MouseDown3StatusLeft display-menu -T "#[align=centre]#{session_name}" -t = -x M -y W Next n { switch-client -n } Previous p { switch-client -p } "" Renumber N { move-window -r } Rename n { command-prompt -I "#S" { rename-session "%%" } } "" "New Session" s { new-session } "New Window" w { new-window } "" "Kill Session" X { kill-session }
      '';
    };
  };
}
