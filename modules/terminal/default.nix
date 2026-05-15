{ pkgs, lib, config, ... }:

let
  ghosttyDefaultApp = pkgs.stdenvNoCC.mkDerivation {
    name = "ghostty-default-app";
    dontUnpack = true;
    installPhase = ''
      app="$out/Applications/ghostty-default.app"
      mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"

      cat > "$app/Contents/Info.plist" <<'PLIST'
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleName</key>
        <string>ghostty-default</string>
        <key>CFBundleDisplayName</key>
        <string>ghostty-default</string>
        <key>CFBundleIdentifier</key>
        <string>org.nix-community.home.ghostty-default</string>
        <key>CFBundleVersion</key>
        <string>1.0</string>
        <key>CFBundleShortVersionString</key>
        <string>1.0</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleExecutable</key>
        <string>ghostty-default</string>
        <key>LSUIElement</key>
        <true/>
      </dict>
      </plist>
      PLIST

      cat > "$app/Contents/MacOS/ghostty-default" <<'SCRIPT'
      #!/bin/sh
      set -eu

      if [ ! -d /Applications/Ghostty.app ]; then
        /usr/bin/osascript -e 'display alert "Ghostty.app not found in /Applications"'
        exit 1
      fi

      # Apps launched from Finder/Dock get launchd's minimal environment. Seed a
      # useful Nix/macOS PATH before asking zsh to run tmux-sessionizer.
      export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

      exec /usr/bin/open -na /Applications/Ghostty.app --args -e /bin/zsh -lic \
        'if command -v tmux-sessionizer >/dev/null 2>&1; then exec tmux-sessionizer; else exec /bin/zsh -l; fi'
      SCRIPT
      chmod +x "$app/Contents/MacOS/ghostty-default"
    '';
  };
in
{
  config = lib.mkIf pkgs.stdenv.isDarwin {
    home.packages = [ ghosttyDefaultApp ];

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
