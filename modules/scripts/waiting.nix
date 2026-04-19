{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "waiting";
      runtimeInputs = with pkgs; [
        coreutils
        bash
      ];

      text = ''
        if [ "''${1:-}" = "--help" ]; then
          echo "Usage: waiting"
          echo "Generates a UUID and waits for a completion signal."
          exit 0
        fi

        UUID=$(cat /proc/sys/kernel/random/uuid)
        echo "Waiting for UUID: $UUID"
        
        SIGNAL_DIR="$HOME/.tmux_signals"
        mkdir -p "$SIGNAL_DIR"
        
        TOUCH_FILE="$SIGNAL_DIR/waiting_$UUID"
        touch "$TOUCH_FILE"
        DONE_FILE="$SIGNAL_DIR/done_$UUID"

        while [ ! -f "$DONE_FILE" ]; do
          sleep 2
        done

        echo "Received message:"
        cat "$DONE_FILE"

        rm "$TOUCH_FILE" "$DONE_FILE"
      '';
    })
  ];
}
