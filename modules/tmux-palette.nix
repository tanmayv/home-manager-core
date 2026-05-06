{ pkgs, userSettings, ... }:

let
  tmux-palette = pkgs.writeScriptBin "tmux-palette" ''
    #!${pkgs.python3}/bin/python3
    import os
    import sys
    import subprocess
    import json

    original_pane = sys.argv[1] if len(sys.argv) > 1 else ""

    current_pane_id = subprocess.check_output(["tmux", "display-message", "-p", "#{pane_id}"], text=True).strip()

    try:
        import tomllib
    except ImportError:
        try:
            import toml as tomllib
        except ImportError:
            print("Error: toml or tomllib not found. Please install it or use Python 3.11+.")
            sys.exit(1)

    config_file = os.path.expanduser("~/.config/tmux-palette/commands.toml")
    history_file = os.path.expanduser("~/.cache/tmux-palette/history.json")

    if not os.path.exists(config_file):
        print(f"Config file not found: {config_file}")
        sys.exit(1)

    with open(config_file, "rb") as f:
        config = tomllib.load(f)

    commands = config.get("commands", [])

    if not commands:
        print("No commands found in config.")
        sys.exit(1)

    # Load history
    history = []
    if os.path.exists(history_file):
        try:
            with open(history_file, "r") as f:
                history = json.load(f)
        except json.JSONDecodeError:
            pass

    # Sort commands based on history
    rank = {name: i for i, name in enumerate(history)}
    default_rank = len(history)

    def get_rank(cmd):
        return rank.get(cmd.get("name"), default_rank)

    commands.sort(key=get_rank)

    max_group_len = max(len(cmd.get("group", "Default")) for cmd in commands)
    max_name_len = max(len(cmd.get("name", "")) for cmd in commands)
    max_mapping_len = max(len(f"({cmd.get('mapping')})") if cmd.get('mapping') else 0 for cmd in commands)
    if max_mapping_len == 0:
        max_mapping_len = 2

    fzf_input = []
    for cmd in commands:
        group = cmd.get("group", "Default")
        name = cmd.get("name", "")
        desc = cmd.get("description", "")
        mapping = cmd.get("mapping", "")
        mapping_str = f"({mapping})" if mapping else ""
        
        group_str = f"[{group}]"
        fzf_input.append(f"{group_str:<{max_group_len + 2}} {name:<{max_name_len}} | {mapping_str:<{max_mapping_len}} | {desc}")

    try:
        process = subprocess.Popen(
            ["${pkgs.fzf}/bin/fzf", "--delimiter=\\|"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True
        )
        stdout, _ = process.communicate(input="\n".join(fzf_input))
    except FileNotFoundError:
        print("Error: fzf is not installed or not in PATH.")
        sys.exit(1)

    selected = stdout.strip()
    if not selected:
        sys.exit(0)

    parts = selected.split(" | ")
    if len(parts) < 3:
        sys.exit(1)

    full_name = parts[0]
    name = full_name.split("] ")[1].strip() if "] " in full_name else full_name.strip()

    for cmd in commands:
        if cmd.get("name") == name:
            command = cmd.get("command")
            
            # Update history
            if name in history:
                history.remove(name)
            history.insert(0, name)
            
            os.makedirs(os.path.dirname(history_file), exist_ok=True)
            with open(history_file, "w") as f:
                json.dump(history, f)
                
            target_pane = original_pane if original_pane else current_pane_id
            command = command.replace("$ORIGINAL_PANE", target_pane)
                
            subprocess.run(command, shell=True)
            sys.exit(0)

    print(f"Command not found for: {name}")
    sys.exit(1)
  '';

in
{
  home.packages = [
    tmux-palette
  ];

  home.file.".config/tmux-palette/commands.toml".text = ''
    [[commands]]
    name = "New Session"
    description = "Create a new tmux session"
    command = 'read -p "New session name: " name && tmux new-session -d -s "$name" && tmux switch-client -t "$name"'
    group = "General"

    [[commands]]
    name = "Command Palette"
    description = "Open command palette"
    command = "tmux-palette"
    group = "General"
    mapping = "C-p"


    [[commands]]
    name = "List Windows"
    description = "List all windows in current session"
    command = "tmux list-windows"
    group = "Navigation"
    mapping = "w"

    [[commands]]
    name = "Switch Workspace"
    description = "Switch to a CitC workspace"
    command = "tmux-sessionizer"
    group = "Navigation"
    mapping = "C-t"

    [[commands]]
    name = "Next Window"
    description = "Switch to next window"
    command = "tmux next-window"
    group = "Windows"
    mapping = "n"

    [[commands]]
    name = "Previous Window"
    description = "Switch to previous window"
    command = "tmux previous-window"
    group = "Windows"
    mapping = "p"

    [[commands]]
    name = "New Window"
    description = "Create a new window"
    command = "tmux new-window"
    group = "Windows"
    mapping = "c"

    [[commands]]
    name = "Kill Window"
    description = "Kill current window"
    command = "tmux kill-window"
    group = "Windows"
    mapping = "&"

    [[commands]]
    name = "Rename Window"
    description = "Rename current window"
    command = 'read -p "New window name: " name && tmux rename-window "$name"'
    group = "Windows"
    mapping = ","

    [[commands]]
    name = "Next Pane"
    description = "Switch to next pane"
    command = "tmux select-pane -t :.+"
    group = "Panes"
    mapping = "o"

    [[commands]]
    name = "Previous Pane"
    description = "Switch to previous pane"
    command = "tmux select-pane -t :.-"
    group = "Panes"

    [[commands]]
    name = "Split Vertical"
    description = "Split window vertically"
    command = "tmux split-window -h"
    group = "Panes"
    mapping = "%"

    [[commands]]
    name = "Split Horizontal"
    description = "Split window horizontally"
    command = "tmux split-window -v"
    group = "Panes"
    mapping = "\""

    [[commands]]
    name = "Kill Pane"
    description = "Kill current pane"
    command = "tmux kill-pane"
    group = "Panes"
    mapping = "x"


    [[commands]]
    name = "Zoom Pane"
    description = "Toggle zoom for current pane"
    command = "tmux resize-pane -Z"
    group = "Panes"
    mapping = "z"

    [[commands]]
    name = "Swap Pane Up"
    description = "Swap current pane with previous"
    command = "tmux swap-pane -U"
    group = "Panes"
    mapping = "{"

    [[commands]]
    name = "Swap Pane Down"
    description = "Swap current pane with next"
    command = "tmux swap-pane -D"
    group = "Panes"
    mapping = "}"

    [[commands]]
    name = "Detach Session"
    description = "Detach from current session"
    command = "tmux detach-client"
    group = "General"
    mapping = "d"

    [[commands]]
    name = "Show Messages"
    description = "Show message log"
    command = "tmux show-messages && read -p 'Press Enter to close...'"
    group = "Utility"
    mapping = "~"

    [[commands]]
    name = "Switch to Last Session"
    description = "Switch to the last active session"
    command = "tmux switch-client -l"
    group = "General"

    [[commands]]
    name = "Reload Configuration"
    description = "Reload tmux configuration"
    command = "tmux source-file ~/.config/tmux/tmux.conf && tmux display-message 'Config reloaded!'"
    group = "Utility"
    mapping = "r"

    [[commands]]
    name = "Build and Switch"
    description = "Rebuild and apply Home Manager configuration"
    command = "build-and-switch && read -p 'Press Enter to close...'"
    group = "Utility"

    [[commands]]
    name = "Edit Home-manager Configuration"
    description = "Select and edit a file in the configuration directory"
    command = 'editor="${userSettings.editor}" && config_location="${userSettings.config-location}" && config_location="''${config_location/#\~/$HOME}" && cd "$config_location" && file=$(find . -type f -not -path "*/.*" | ${pkgs.fzf}/bin/fzf) && [[ -n "$file" ]] && tmux new-window -c "$(pwd)" -n "edit-config" "$editor $file"'
    group = "Utility"

    [[commands]]
    name = "Search File via CodeSearch"
    description = "Interactive CodeSearch with fzf and preview"
    command = "tmux-cs-fzf"
    group = "Navigation"
    mapping = "C-s"

    [[commands]]
    name = "Create Knowledge Note"
    description = "Create a new note in the knowledge directory and edit it in a popup"
    command = "knowledge-manager create"
    group = "AI"

    [[commands]]
    name = "Open/List Knowledge Notes"
    description = "Fuzzy search and read/edit knowledge notes"
    command = "knowledge-manager list"
    group = "AI"

    [[commands]]
    name = "Run Agent in Current Directory"
    description = "List all agents and run the selected agent in zsh or new window"
    command = "new-gemini-agent"
    group = "AI"

    [[commands]]
    name = "Rename Agent"
    description = "Rename the agent in the current pane"
    command = 'read -p "New agent name: " new_name && [[ -n "$new_name" ]] && tmux-rename-agent "$ORIGINAL_PANE" "$new_name"'
    group = "AI"

    ${if userSettings.enable-smart-cd or false then ''
    [[commands]]
    name = "Search directory with CodeSearch"
    description = "Interactive CodeSearch for directories and switch to it in a new window"
    command = "tmux-cs-cd"
    group = "Navigation"

    [[commands]]
    name = "Open Recent Directories"
    description = "Open recent directory in new window"
    command = 'target=$(zsh -i -c "cd -i --print") && [[ -n "$target" ]] && tmux new-window -c "$target"'
    group = "Navigation"
    '' else ""}
  '';
}
