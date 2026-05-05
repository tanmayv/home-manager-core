{ config, pkgs, inputs, ... }:

let
  tmux-create-task = pkgs.writeShellApplication {
    name = "tmux-create-task";
    runtimeInputs = with pkgs; [ coreutils bash neovim ];
    text = ''
      workspace=""
      if [[ -n "$TMUX" ]]; then
        workspace=$(tmux display-message -p '#S')
      fi

      if [[ -n "$workspace" ]]; then
        ${pkgs.neovim}/bin/nvim ~/pkm/tasks.md -c "TaskAdd $workspace"
      else
        ${pkgs.neovim}/bin/nvim ~/pkm/tasks.md -c "TaskAdd"
      fi
    '';
  };

  tmux-create-note = pkgs.writeShellApplication {
    name = "tmux-create-note";
    runtimeInputs = with pkgs; [ coreutils bash neovim ripgrep ];
    text = ''
      note_path=$(nn --print-path)
      
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
in
{
  home.packages = [
    inputs.tasks-nvim.packages.${pkgs.system}.default
    tmux-create-task
    tmux-create-note
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
  '';
}
