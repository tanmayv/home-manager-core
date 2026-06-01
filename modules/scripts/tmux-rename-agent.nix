{ pkgs, config, ... }:

{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "tmux-rename-agent";
      runtimeInputs = (with pkgs; [
        tmux
        coreutils
        gnused
      ]) ++ [ config.programs.broccoli-comms.package ];

      text = ''
        original_pane="''${1:-}"
        new_name="''${2:-}"

        if [[ -z "$original_pane" ]]; then
            echo "Error: Original pane ID not provided."
            echo "Usage: tmux-rename-agent <original_pane> <new_name>"
            read -r -p "Press Enter to exit..."
            exit 1
        fi

        if [[ -z "$new_name" ]]; then
            echo "Error: New agent name not provided."
            echo "Usage: tmux-rename-agent <original_pane> <new_name>"
            read -r -p "Press Enter to exit..."
            exit 1
        fi

        # Check if the pane has @agent_name set
        agent_name=$(tmux show-option -p -v -t "$original_pane" @agent_name || true)
        
        if [[ -z "$agent_name" ]]; then
            echo "Error: No agent running in pane $original_pane (or @agent_name not set)."
            read -r -p "Press Enter to exit..."
            exit 1
        fi

        echo "Found agent '$agent_name' in pane $original_pane."
        echo "Renaming to '$new_name'..."
        
        # Run through Broccoli Comms so the app-owned tracker is used.
        if broccoli-comms agent-tracker rename --force "$agent_name" "$new_name"; then
            echo "Successfully renamed agent."
        else
            echo "Failed to rename agent."
            read -r -p "Press Enter to exit..."
            exit 1
        fi
        
        sleep 1
      '';
    })
  ];
}
