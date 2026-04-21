{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "tmux-cs-cd";
      runtimeInputs = with pkgs; [
        fzf
        coreutils
        gnused
        gnugrep
      ];

      text = ''
        if [[ "$PWD" != /google/src/cloud/$USER/*/google3* ]]; then
            echo "Error: Must be run from within a google3 workspace."
            read -r -p "Press Enter to exit..."
            exit 1
        fi
        
        HISTORY_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/tmux-cs-cd"
        HISTORY_FILE="$HISTORY_DIR/history.txt"

        mkdir -p "$HISTORY_DIR"
        touch "$HISTORY_FILE"

        output=$(fzf --prompt="CS Dir Query (Enter: match, Ctrl-X: exact)> " --print-query --expect=ctrl-x < "$HISTORY_FILE" || true)
        
        if [[ -z "$output" ]]; then
            exit 0
        fi
        
        query_line=$(echo "$output" | sed -n '1p')
        key_pressed=$(echo "$output" | sed -n '2p')
        selected_line=$(echo "$output" | sed -n '3p')

        if [[ "$key_pressed" == "ctrl-x" ]]; then
            query="$query_line"
        elif [[ -n "$selected_line" ]]; then
            query="$selected_line"
        else
            query="$query_line"
        fi

        if [[ -z "$query" ]]; then
            exit 0
        fi

        # Run cd --cs --print and capture output
        # fzf will run inside the subshell and have access to tty
        target=$(zsh -i -c 'cd --cs --print "$1"' -- "$query")

        if [[ -n "$target" ]]; then
            # Save query to history
            grep -vxF "$query" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" || true
            echo "$query" > "$HISTORY_FILE"
            cat "$HISTORY_FILE.tmp" >> "$HISTORY_FILE"
            rm -f "$HISTORY_FILE.tmp"
            
            head -n 100 "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"

            # Open in a new tmux window
            if [[ -n "''${TMUX:-}" ]]; then
                tmux new-window -c "$target"
            else
                cd "$target"
            fi
        fi
      '';
    })
  ];
}
