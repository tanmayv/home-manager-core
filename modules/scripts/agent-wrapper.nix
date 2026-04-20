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
          user_name=$(whoami)
          current_session=$(tmux display-message -p '#S')
          
          ws="local"
          # SC2295: Expansions inside ''${..} need to be quoted separately
          if [[ "$PWD" == /google/src/cloud/"$user_name"/* ]]; then
            ws_part="''${PWD#/google/src/cloud/"$user_name"/}"
            ws="''${ws_part%%/*}"
          fi
          
          # Find all agent names in current session to find next available number
          existing_agents=$(tmux list-panes -a -F "#S #{@agent_name}" | grep "^''${current_session} " | cut -d' ' -f2- | grep -v "^$" || true)
          
          next_num=1
          while echo "$existing_agents" | grep -q "^''${ws}-agent-''${next_num}$"; do
            next_num=$((next_num + 1))
          done
          
          agent_name="''${ws}-agent-''${next_num}"
          tmux set-option -p @agent_name "$agent_name"
          tmux select-pane -T "$agent_name"
          
          # Refresh status bar to show the new agent
          tmux-status-refresh
        fi
        
        # Run the tool
        "$cmd" "$@"

        if [[ -n "''${TMUX:-}" ]]; then
          # Reset after the command finishes
          tmux set-option -p -u @agent_name
          tmux select-pane -T ""
          # Refresh status bar to remove the agent
          tmux-status-refresh
        fi
      '';
    })
  ];
}
