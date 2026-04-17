{ pkgs, ... }:

let
  tmux-palette = pkgs.writeScriptBin "tmux-palette" ''
    #!${pkgs.python3}/bin/python3
    import os
    import sys
    import subprocess
    import json

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
            ["fzf", "--delimiter=\\|"],
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
}
