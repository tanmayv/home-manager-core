{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "agent-wrapper";
      runtimeInputs = with pkgs; [
        tmux
        coreutils
        gnugrep
      ];

      text = ''
        cmd="$1"
        shift
        
        if [[ -n "''${TMUX:-}" ]]; then
          pane_id=$(tmux display-message -p '#{pane_id}')
          session_name=$(tmux display-message -p '#S')
          
          # Start the setup and injection in background to allow tool to start in foreground
          (
            # 1. Figure out name
            # We do this inside the subshell but we need to be careful about race conditions.
            # However, for TUI to work, the main script MUST foreground the command.
            
            existing_agents_raw=$(tmux list-panes -a -F "#S #{@agent_name}" | grep "^''${session_name} " | cut -d' ' -f2- | grep -v "^$" || true)
            
            next_num=1
            while echo "$existing_agents_raw" | grep -q "^''${session_name}-agent-''${next_num}$"; do
              next_num=$((next_num + 1))
            done
            
            agent_name="''${session_name}-agent-''${next_num}"
            
            # 2. Set identity
            tmux set-option -p -t "''${pane_id}" @agent_name "$agent_name"
            tmux select-pane -t "''${pane_id}" -T "$agent_name"
            tmux-status-refresh
            
            # 3. Gather others for context
            all_agents=$(tmux list-panes -a -F "Agent: #{@agent_name} | Location: #{pane_id}" | grep -v "Agent:  |" || true)
            
            context="Note: You are ''${agent_name} in pane ''${pane_id}.
Currently active agents in this environment:
''${all_agents}"

            # 4. Inject context (wait for TUI to be ready)
            sleep 2
            tmux send-keys -t "''${pane_id}" "From: system | ''${context}" C-m
          ) &
          
          # Run the tool in FOREGROUND to keep TUI interactive
          "$cmd" "$@"

          # Cleanup
          tmux set-option -p -u @agent_name
          tmux select-pane -T ""
          tmux-status-refresh
        else
          # Fallback for non-tmux environments
          "$cmd" "$@"
        fi
      '';
    })
  ];
}
