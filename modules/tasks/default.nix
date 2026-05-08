{ config, pkgs, inputs, lib, ... }:

with lib;

let
  cfg = config.programs.tasks;

  tmux-create-task = pkgs.writeShellApplication {
    name = "tmux-create-task";
    runtimeInputs = with pkgs; [ coreutils bash neovim fzf findutils gnugrep ];
    text = ''
      workspace_list=""
      ${concatStringsSep "\n" (map (path: ''
        if [ -d "${path}" ]; then
          workspace_list=$(printf "%s\n%s" "$workspace_list" "$(find "${path}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n')")
        fi
      '') cfg.workspaceSearchPaths)}
      
      if command -v tmux &>/dev/null; then
        workspace_list=$(printf "%s\n%s" "$workspace_list" "$(tmux list-sessions -F '#S' 2>/dev/null)")
      fi
      
      workspace=$(echo "$workspace_list" | grep -v '^$' | sort -u | fzf --prompt="Select Workspace: ")

      if [[ -z "$workspace" ]]; then
        echo "No workspace selected. Aborting."
        exit 1
      fi

      ${pkgs.neovim}/bin/nvim ~/pkm/tasks.md -c "TaskAdd $workspace"
    '';
  };

  tmux-create-note = pkgs.writeShellApplication {
    name = "tmux-create-note";
    runtimeInputs = with pkgs; [ coreutils bash neovim ripgrep fzf findutils gnugrep ];
    text = ''
      workspace_list=""
      ${concatStringsSep "\n" (map (path: ''
        if [ -d "${path}" ]; then
          workspace_list=$(printf "%s\n%s" "$workspace_list" "$(find "${path}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n')")
        fi
      '') cfg.workspaceSearchPaths)}
      
      if command -v tmux &>/dev/null; then
        workspace_list=$(printf "%s\n%s" "$workspace_list" "$(tmux list-sessions -F '#S' 2>/dev/null)")
      fi
      
      workspace=$(echo "$workspace_list" | grep -v '^$' | sort -u | fzf --prompt="Select Workspace: ")

      if [[ -z "$workspace" ]]; then
        echo "No workspace selected. Aborting."
        exit 1
      fi

      note_path=$(nn --print-path --workspace="$workspace")
      
      if [[ -z "$note_path" ]]; then
        exit 1
      fi

      note_filename="''${note_path##*/}"

      original_content=$(cat "$note_path")

      ${pkgs.neovim}/bin/nvim "$note_path"

      updated_content=$(cat "$note_path")

      if [[ "$original_content" == "$updated_content" ]]; then
        rm "$note_path"

        if [[ -d ~/pkm ]]; then
          grep -rl "dots/''${note_filename}" ~/pkm/journal ~/pkm/workspace 2>/dev/null | while read -r file; do
            grep -v "dots/''${note_filename}" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
          done
        fi
      fi
    '';
  };
      tmux-task-stats = pkgs.writeShellApplication {
    name = "tmux-task-stats";
    runtimeInputs = with pkgs; [ coreutils bash jq ];
    text = ''
      workspace="$1"
      stats=$(task stats "@$workspace" --json)
      
      due=$(echo "$stats" | jq -r '.due // 0')
      open=$(echo "$stats" | jq -r '.open // 0')
      closed=$(echo "$stats" | jq -r '.closed // 0')

      echo "#[fg=red]$due#[fg=default]/#[fg=yellow]$open#[fg=default]/#[fg=green]$closed"
    '';
  };

in
{
  config = {
    home.packages = [
      inputs.tasks-nvim.packages.${pkgs.system}.default
      tmux-create-task
      tmux-create-note
      tmux-task-stats
    ];

    xdg.configFile."task-manager-tui/config.json".text = ''
      {
        "db_path": "~/.local/share/nvim/task_manager.db",
        "inbox_file": "~/pkm/tasks.md",
        "directories": ["~/pkm"],
        "auto_tags": {
          "/daily/": ["daily"]
        }
      }
    '';

    programs.tmux.extraConfig = ''
      bind-key C-c display-popup -w 95% -h 80% -E "${tmux-create-note}/bin/tmux-create-note || sleep 5000"
      bind-key T display-popup -w 95% -h 80% -E "${tmux-create-task}/bin/tmux-create-task || sleep 5000"
      bind-key t display-popup -w 95% -h 80% -E "bash -c 'S=\$(tmux display-message -p \"#S\"); task -p \"\$S\"'"
      bind-key -T root MouseDown1StatusLeft display-popup -w 95% -h 80% -E "bash -c 'S=\$(tmux display-message -p \"#S\"); task -p \"\$S\"'"
      set -g status-left-length 60
      set -g status-left "#{?client_prefix,#[reverse],#[fg=#bb9af7]}[#S]#[default] #(tmux-task-stats '#S') "
    '';
  };
  options.programs.tasks = {
    workspaceSearchPaths = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Paths to search for workspaces for task association.";
    };
  };
}
