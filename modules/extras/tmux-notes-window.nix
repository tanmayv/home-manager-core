{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "tmux-notes-window";
  runtimeInputs = with pkgs; [
    zk
    coreutils
    bash
    tmux
    neovim
  ];

  text = ''
    if [ -z "$TMUX" ]; then
      echo "Not in a tmux session"
      exit 1
    fi

    SESSION_NAME=$(tmux display-message -p '#S')
    WINDOW_NAME="Notes"

    if tmux list-windows -t "$SESSION_NAME" | grep -q ": $WINDOW_NAME"; then
      tmux select-window -t "$SESSION_NAME:$WINDOW_NAME"
    else
      tmux new-window -n "$WINDOW_NAME"
      tmux select-window -t "$SESSION_NAME:$WINDOW_NAME"
      tmux select-pane -t 0
      tmux split-window -h

      tmux select-pane -t 0
      tmux send-keys "while true; do nd; done" C-m
      tmux split-window -v

      if [[ -f "$HOME/pkm/workspace/$SESSION_NAME.md" ]]; then
        # If the file exists, open that specific file
        tmux send-keys "while true; do nvim $HOME/pkm/workspace/$SESSION_NAME.md; done" C-m;
      else
        # If the file does NOT exist, just open the workspace directory
        tmux send-keys "while true; do nvim $HOME/pkm/workspace; done" C-m;
      fi

      tmux select-pane -t 2
      tmux send-keys "while true; do nvim $HOME/pkm/tasks.md; done" C-m
    fi
  '';
}
