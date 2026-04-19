{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "ask-duckie-context";
      runtimeInputs = with pkgs; [
        tmux
      ];

      text = ''
        read -r -p "Ask Duckie: " QUERY
        
        if [[ -z "$QUERY" ]]; then
          exit 0
        fi

        # Capture the underlying pane context. We use -t "{active}" to get the active pane of the current window.
        CONTEXT=$(tmux capture-pane -p -S -100 -t "{active}" 2>/dev/null || true)
        
        # We construct the prompt
        PROMPT="Please ask Duckie: $QUERY. Here is the context of my current terminal pane for reference:

$CONTEXT"

        # Create a temporary script that runs gemini and cleans up
        # We do this so we don't have to worry about escaping multiline strings in the tmux command
        RUNNER_SCRIPT=$(mktemp)
        PROMPT_FILE=$(mktemp)
        
        echo "$PROMPT" > "$PROMPT_FILE"
        
        cat <<EOF > "$RUNNER_SCRIPT"
#!/usr/bin/env bash
gemini -i "\$(cat $PROMPT_FILE)"
rm -f "$PROMPT_FILE" "$RUNNER_SCRIPT"
EOF
        
        chmod +x "$RUNNER_SCRIPT"
        tmux split-window -h "$RUNNER_SCRIPT"
      '';
    })
  ];
}
