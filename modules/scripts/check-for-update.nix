{ pkgs, userSettings, ... }:

{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "check-for-update";
      runtimeInputs = with pkgs; [ coreutils ];
      text = ''
        # shellcheck disable=SC2088
        CONFIG_DIR="${userSettings.config-location}"
        CONFIG_DIR="''${CONFIG_DIR/#\~/$HOME}"
        CACHE_FILE="$HOME/.cache/minimal-cloudtop-update-check"

        if [ ! -d "$CONFIG_DIR/.git" ]; then exit 0; fi

        cd "$CONFIG_DIR" || exit 0

        current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)
        if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
          exit 0
        fi

        # Check once a day
        if [ -f "$CACHE_FILE" ]; then
          # Fallback to 0 if stat fails, with GNU/BSD stat compatibility.
          if stat -c %Y "$CACHE_FILE" >/dev/null 2>&1; then
            last_check=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
          else
            last_check=$(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
          fi
          now=$(date +%s)
          if [ $((now - last_check)) -lt 86400 ]; then
            exit 0
          fi
        fi
        
        mkdir -p "$(dirname "$CACHE_FILE")"
        touch "$CACHE_FILE"

        # Fetch stable tag from origin
        git fetch origin tag stable --no-tags >/dev/null 2>&1 || exit 0

        # Check if stable is ahead of HEAD
        if git merge-base --is-ancestor HEAD stable 2>/dev/null; then
          # HEAD is an ancestor of stable. Are they different?
          if [ "$(git rev-parse HEAD)" != "$(git rev-parse stable)" ]; then
            echo ""
            echo "========================================================="
            echo "🎉 A new stable version of Minimal Cloudtop is available!"
            echo "========================================================="
            read -r -p "Would you like to update now? [y/N] " response
            if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
              echo "Updating..."
              # Rebase current branch onto the new stable tag
              if git rebase origin/stable; then
                build-and-switch
              else
                echo "Rebase conflict detected! Please resolve conflicts manually and then run 'build-and-switch'."
                git rebase --abort || true
              fi
            fi
          fi
        fi
      '';
    })
  ];
}
