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
            FILE="$NAME"
            if [[ "$FILE" != *.md ]]; then
                FILE="$FILE.md"
            fi
            # Open editor in a popup for quick creation
            tmux display-popup -w 95% -h 90% -d "$KNOWLEDGE_DIR" -E "${userSettings.editor} \"$FILE\""
        elif [[ "$MODE" == "list" || "$MODE" == "open" ]]; then
            FILE=$(find . -type f -name "*.md" 2>/dev/null | fzf --preview "bat --color=always --style=numbers {}" --header "Select a note to open")
            if [[ -n "$FILE" ]]; then
                # Open existing notes in a new window for better reading/editing
                tmux new-window -c "$KNOWLEDGE_DIR" -n "knowledge" "${userSettings.editor} \"$FILE\""
            fi
        fi
      '';
    })
  ];
}
