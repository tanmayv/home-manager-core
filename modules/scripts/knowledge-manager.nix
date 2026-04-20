{ pkgs, userSettings, ... }:

{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "knowledge-manager";
      runtimeInputs = with pkgs; [
        tmux
        fzf
        bat
        coreutils
        findutils
        gnused
      ];

      text = ''
        # shellcheck disable=SC2088
        KNOWLEDGE_DIR_RAW="${userSettings.local_agent_knowledge_dir}"
        # If it starts with ~, replace with $HOME
        KNOWLEDGE_DIR="''${KNOWLEDGE_DIR_RAW/#\~/$HOME}"
        mkdir -p "$KNOWLEDGE_DIR"
        cd "$KNOWLEDGE_DIR"

        MODE="''${1:-open}"

        if [[ "$MODE" == "list" ]]; then
            FILE=$(find . -type f -name "*.md" 2>/dev/null | fzf --preview "bat --color=always --style=numbers {}")
            if [[ -n "$FILE" ]]; then
                tmux new-window -c "$KNOWLEDGE_DIR" -n "knowledge" "${userSettings.editor} \"$FILE\""
            fi
        else
            SELECTION=$(find . -type f -name "*.md" 2>/dev/null | fzf --print-query --header "Select a note or type a new name")
            if [[ -n "$SELECTION" ]]; then
                QUERY=$(echo "$SELECTION" | sed -n '1p')
                MATCH=$(echo "$SELECTION" | sed -n '2p')
                
                if [[ -n "$MATCH" ]]; then
                    FILE="$MATCH"
                else
                    FILE="$QUERY"
                fi

                if [[ -n "$FILE" ]]; then
                    if [[ "$FILE" != *.md ]]; then
                        FILE="$FILE.md"
                    fi
                    tmux new-window -c "$KNOWLEDGE_DIR" -n "knowledge" "${userSettings.editor} \"$FILE\""
                fi
            fi
        fi
      '';
    })
  ];
}
