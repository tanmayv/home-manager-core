{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "tmux-cs-fzf";
      runtimeInputs = with pkgs; [
        fzf
        bat
        coreutils
        gnugrep
        gnused
      ];

      text = ''
        if [[ "$PWD" != /google/src/cloud/$USER/*/google3* ]]; then
            echo "Error: Must be run from within a google3 workspace."
            read -r -p "Press Enter to exit..."
            exit 1
        fi
        
        WORKSPACE_ROOT="''${PWD%%/google3*}/google3"

        HISTORY_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/tmux-cs-fzf"
        HISTORY_FILE="$HISTORY_DIR/history.txt"

        mkdir -p "$HISTORY_DIR"
        touch "$HISTORY_FILE"

        # Use --expect to distinguish between selecting an item and executing the exact query
        output=$(fzf --prompt="CS Query (Enter: match, Ctrl-X: exact)> " --print-query --expect=ctrl-x < "$HISTORY_FILE")
        
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

        # Run cs and pipe to fzf. Discard stderr to prevent UI corruption from summary lines.
        # Strip the absolute path up to /google3/ so paths are relative to the workspace.
        # Uses delimiter ":" since cs outputs in the format "file:line:content"
        selected=$(cs "$query" 2>/dev/null | sed 's|^.*/google3/||' | fzf \
            --delimiter=":" \
            --preview="bat --color=always --style=numbers --highlight-line {2} {1} 2>/dev/null || cat {1} 2>/dev/null" \
            --preview-window="top:60%:border-sharp" \
            --prompt="Results> ")

        if [[ -n "$selected" ]]; then
            # Save query to history
            # Remove old instance of the query to move it to the top
            grep -vxF "$query" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" || true
            echo "$query" > "$HISTORY_FILE"
            cat "$HISTORY_FILE.tmp" >> "$HISTORY_FILE"
            rm -f "$HISTORY_FILE.tmp"
            
            # Keep only the last 100 items
            head -n 100 "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"

            # Open the file
            file=$(echo "$selected" | cut -d: -f1)
            line=$(echo "$selected" | cut -d: -f2)
            
            editor="''${EDITOR:-nvim}"
            
            # Open in a new tmux window relative to the workspace root
            if [[ -n "''${TMUX:-}" ]]; then
                tmux new-window -c "$WORKSPACE_ROOT" -n "cs-edit" "$editor +$line \"$file\""
            else
                (cd "$WORKSPACE_ROOT" && $editor "+$line" "$file")
            fi
        fi
      '';
    })
  ];
}
