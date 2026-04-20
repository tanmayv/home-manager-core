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
          
          # Find all agent names in current session to find next available number
          existing_agents_raw=$(tmux list-panes -a -F "#S #{@agent_name}" | grep "^''${session_name} " | cut -d' ' -f2- | grep -v "^$" || true)
          
          next_num=1
          while echo "$existing_agents_raw" | grep -q "^''${session_name}-agent-''${next_num}$"; do
            next_num=$((next_num + 1))
          done
          
          agent_name="''${session_name}-agent-''${next_num}"
          
          # Gather all agents across all sessions for the initial prompt
          all_agents=$(tmux list-panes -a -F "Agent: #{@agent_name} | Location: #{pane_id}" | grep -v "Agent:  |" || true)
          
          # Set identity
          tmux set-option -p @agent_name "$agent_name"
          tmux select-pane -T "$agent_name"
          
          # Refresh status bar
          tmux-status-refresh
          
          # Initial prompt context
          context="Note: You are ''${agent_name} in pane ''${pane_id}.
Currently active agents in this environment:
''${all_agents}"

          # Start the tool in background
          "$cmd" "$@" &
          agent_pid=$!
          
          # Send the initial context prompt in parallel
          (
            # Wait a moment for the CLI to initialize and be ready for input
            sleep 1.5
            # We follow our own 'From: system' protocol
            tmux send-keys -t "''${pane_id}" "From: system | ''${context}" C-m
          ) &
          
          # Wait for the agent to finish
          wait "$agent_pid"

          # Reset after the command finishes
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
