{ pkgs, ... }:

pkgs.writeShellApplication {
  name = "wn";
  runtimeInputs = with pkgs; [
    zk
    coreutils
    bash
    tmux
    neovim
  ];

  text = ''
    pkm_root="$HOME/pkm"

    if [[ -z "''${TMUX:-}" ]]; then
      echo "Error: Not inside a tmux session."
      exit 1
    fi

    ws_match=$(tmux display-message -p '#S')
  
    note_dir="$HOME/pkm/workspace/''${ws_match}"
  
    # Create the directory if it doesn't exist
    mkdir -p "$note_dir"
  
    current_pwd="$HOME/pkm/workspace"

    note_path=$(zk new -p --working-dir="$current_pwd" --template="$HOME/.config/zk/templates/workspace-main.md" --extra=ws="$ws_match" --id="$ws_match")
    nvim -c "cd ''${pkm_root}" "$note_path"
  '';
}
