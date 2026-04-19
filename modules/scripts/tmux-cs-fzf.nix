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
      ];

      text = ''
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

        # Run cs and pipe to fzf.
        # Uses delimiter ":" since cs outputs in the format "file:line:content"
        selected=$(cs "$query" | fzf \
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
            
            # Open in a new tmux window
            if [[ -n "''${TMUX:-}" ]]; then
                tmux new-window -n "cs-edit" "$editor +$line \"$file\""
            else
                $editor "+$line" "$file"
            fi
        fi
      '';
    })
  ];
}
