{ pkgs, ... }:

pkgs.writeShellApplication {
  name = "cl-copy";
  runtimeInputs = with pkgs; [
    tmux
    coreutils
    bash
  ];

  text = ''
    # Use tmux set-buffer -w to copy to tmux buffer and system clipboard (via OSC 52)
    text="$1"
    tmux set-buffer -w "$text"
    tmux display-message "Copied to clipboard: $text"
  '';
}
