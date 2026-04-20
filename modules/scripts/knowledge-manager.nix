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

        if [[ "$MODE" == "create" ]]; then
            read -r -p "Note name: " NAME
            if [[ -z "$NAME" ]]; then
                exit 0
            fi
            
            read -r -p "Command (Enter for ${userSettings.editor}): " CMD

            FILE="$NAME"
            if [[ "$FILE" != *.md ]]; then
                FILE="$FILE.md"
            fi

            if [[ -z "$CMD" ]]; then
                FINAL_CMD="${userSettings.editor} '$FILE'"
            else
                FINAL_CMD="$CMD"
            fi

            # Open in a popup. We use bash -c to ensure cd happens before command starts.
            tmux display-popup -w 95% -h 90% -d "$KNOWLEDGE_DIR" -E "bash -c \"cd '$KNOWLEDGE_DIR' && $FINAL_CMD\""
        elif [[ "$MODE" == "list" || "$MODE" == "open" ]]; then
            FILE=$(find . -type f -name "*.md" 2>/dev/null | fzf --preview "bat --color=always --style=numbers {}" --header "Select a note to open")
            if [[ -n "$FILE" ]]; then
                # Open existing notes in a new window for better reading/editing
                tmux new-window -c "$KNOWLEDGE_DIR" -n "knowledge" "bash -c \"cd '$KNOWLEDGE_DIR' && ${userSettings.editor} '$FILE'\""
            fi
        fi
      '';
    })
  ];
}
