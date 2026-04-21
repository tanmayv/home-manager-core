{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "new-gemini-agent";
      runtimeInputs = with pkgs; [
        fzf
        tmux
        coreutils
        gnugrep
        findutils
      ];

      text = ''
        # Find target pane (the one active before the popup)
        TARGET_PANE=$(tmux display-message -p '#{last_pane_id}')
        
        if [ -z "$TARGET_PANE" ]; then
          TARGET_PANE=$(tmux list-panes -F "#{pane_id} #{pane_active}" | grep " 1$" | cut -d' ' -f1)
          echo "Fallback to active pane=$TARGET_PANE" > /tmp/new-gemini-agent.log
        else
          echo "Used last_pane_id=$TARGET_PANE" > /tmp/new-gemini-agent.log
        fi

        all_agents=("gemini" "jetski")

        # Use fzf to select one
        selected=$(printf "%s\n" "''${all_agents[@]}" | fzf --prompt="Select Agent: ")

        if [ -z "$selected" ]; then
          exit 0
        fi

        cmd_base="$selected"

        TARGET_PATH=$(tmux display-message -t "$TARGET_PANE" -p '#{pane_current_path}')

        # Ask user where to run
        choice=$(echo -e "1. Current Pane\n2. Vertical Split\n3. Horizontal Split" | fzf --prompt="Run in: ")

        if [[ "$choice" == *"Current Pane"* ]]; then
          # Run in target pane (using send-keys)
          tmux send-keys -t "$TARGET_PANE" "$cmd_base" C-m
        elif [[ "$choice" == *"Vertical Split"* ]]; then
          # Split window vertically and run
          tmux split-window -h -t "$TARGET_PANE" -c "$TARGET_PATH" "$cmd_base ; zsh"
        else
          # Split window horizontally and run
          tmux split-window -v -t "$TARGET_PANE" -c "$TARGET_PATH" "$cmd_base ; zsh"
        fi
      '';
    })
  ];
}
