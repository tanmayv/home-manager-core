{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "send-message-to-agent";
      runtimeInputs = with pkgs; [
        coreutils
        util-linux
        tmux
      ];

      text = ''
        if [ "$#" -lt 2 ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
          echo "Usage: send-message-to-agent <target_location> <message>"
          echo "Sends a message to a tmux pane/window using send-keys, with locking."
          exit 0
        fi

        TARGET="$1"
        shift
        MESSAGE="$*"

        LOCKFILE="/tmp/agent_tmux.lock"

        (
          if ! flock -n 200; then
            echo "Waiting for lock on $LOCKFILE..."
            # Wait for 10 seconds
            flock -x -w 10 200 || { echo "Error: Timeout waiting for lock after 10 seconds"; exit 1; }
          fi
          
          tmux send-keys -t "$TARGET" "$MESSAGE" C-m
          
        ) 200>"$LOCKFILE"
      '';
    })
  ];
}
