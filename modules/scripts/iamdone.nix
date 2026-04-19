{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "iamdone";
      runtimeInputs = with pkgs; [
        coreutils
        bash
      ];

      text = ''
        if [ "$1" = "--help" ]; then
          echo "Usage: iamdone <UUID> [message]"
          echo "Signals completion for a waiting process identified by UUID."
          exit 0
        fi

        if [ "$#" -lt 1 ]; then
          echo "Usage: iamdone <UUID> [message]"
          exit 1
        fi
        
        UUID=$1
        MSG="''${*:2}"
        MSG="''${MSG:-Done}"
        
        SIGNAL_DIR="$HOME/.tmux_signals"
        TOUCH_FILE="$SIGNAL_DIR/waiting_$UUID"
        DONE_FILE="$SIGNAL_DIR/done_$UUID"

        if [ -f "$TOUCH_FILE" ]; then
          echo "$MSG" > "$DONE_FILE"
          echo "Signaled completion for $UUID"
        else
          echo "Error: No waiting process found for $UUID"
          exit 1
        fi
      '';
    })
  ];
}
