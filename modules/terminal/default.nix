{ pkgs, lib, config, ... }:

{
  config = lib.mkIf pkgs.stdenv.isDarwin {
    # Ghostty ships its own terminfo outside the standard ncurses search path on
    # macOS. SSH only forwards TERM=xterm-ghostty, not TERMINFO, so remote
    # machines need a copy in ~/.terminfo for curses/tmux/nvim to work.
    home.activation.installGhosttyTerminfo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ghostty_terminfo="/Applications/Ghostty.app/Contents/Resources/terminfo"
      if [ -d "$ghostty_terminfo" ]; then
        mkdir -p "$HOME/.terminfo"
        cp -R "$ghostty_terminfo"/. "$HOME/.terminfo"/
      fi
    '';
  };
}
