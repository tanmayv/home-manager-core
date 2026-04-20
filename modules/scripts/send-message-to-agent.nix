{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "send-message-to-agent";
      runtimeInputs = with pkgs; [
        coreutils
        util-linux
        tmux
        gnugrep
      ];

      text = ''
        if [ "$#" -lt 2 ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
          echo "Usage: send-message-to-agent <target_location_or_name> <message>"
          echo "Sends a message to a tmux pane/window using send-keys, with locking."
          echo "Target can be a pane ID (e.g. %10), index (e.g. 0:1.0), or agent name (e.g. nixcloud-agent-1)."
          exit 0
        fi

        TARGET="$1"
        shift
        MESSAGE="$*"

        # Check if TARGET is an agent name (doesn't start with % or look like session:window.pane)
        if [[ ! "$TARGET" =~ ^%[0-9]+$ ]] && [[ ! "$TARGET" =~ ^[0-9]+:[0-9]+\.[0-9]+$ ]]; then
          # Try to find a pane with matching @agent_name
          found_pane=$(tmux list-panes -a -F "#{pane_id} #{@agent_name}" | grep " ''${TARGET}$" | cut -d' ' -f1 | head -n 1 || true)
          if [[ -n "$found_pane" ]]; then
            TARGET="$found_pane"
          fi
        fi

        LOCKFILE="/tmp/agent_tmux.lock"

        (
          if ! flock -n 200; then
            echo "Waiting for lock on $LOCKFILE..."
            # Wait for 10 seconds
            flock -x -w 10 200 || { echo "Error: Timeout waiting for lock after 10 seconds"; exit 1; }
          fi
          
          tmux send-keys -t "$TARGET" "$MESSAGE"
          sleep 0.1
          tmux send-keys -t "$TARGET" C-m
          
        ) 200>"$LOCKFILE"
      '';
    })
  ];
}
