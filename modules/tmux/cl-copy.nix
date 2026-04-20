{ pkgs, ... }:

pkgs.writeShellApplication {
  name = "cl-copy";
  runtimeInputs = with pkgs; [
    coreutils
    bash
  ];

  text = ''
    # Use OSC 52 to copy to system clipboard
    # Input is the text to copy
    text="$1"
    
    # Base64 encode the text
    encoded=$(echo -n "$text" | base64 | tr -d '\n')
    
    # OSC 52 sequence: \e]52;c;ENCODED_TEXT\a
    # We use tmux set-buffer and then load-buffer to send the escape sequence if needed,
    # but tmux 'set-buffer -w' is the standard way to trigger OSC 52.
    
    tmux set-buffer "$text"
    tmux display-message "Copied CL: $text to tmux buffer"
    
    # Also try to trigger system clipboard via OSC 52 if supported by terminal
    printf "\033]52;c;%s\007" "$encoded"
  '';
}
