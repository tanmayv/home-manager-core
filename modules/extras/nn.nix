{ pkgs, username, ... }:
pkgs.writeShellApplication {
  name = "nn";
  runtimeInputs = with pkgs; [
    zk
    coreutils
    bash
  ];

  text = ''
    print_path=false
    ws_override=""
    title_override=""

    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        --print-path)
          print_path=true
          shift
          ;;
        --workspace=*)
          ws_override="''${1#*=}"
          shift
          ;;
        --title=*)
          title_override="''${1#*=}"
          shift
          ;;
        *)
          break
          ;;
      esac
    done

    current_pwd=$(pwd)
    user="${username}"
    note_root="$HOME/pkm/dots"
    ws_match="$ws_override"
    title="''${title_override}"

    if [[ -z "$title" ]]; then
      title="''${current_pwd##*/}"
    fi

    if [[ -z "$ws_match" ]]; then
      # Check if the path contains /user/workspace/google3
      ws_regex="/''${user}/([^/]+)/google3"
      if [[ "$current_pwd" =~ $ws_regex ]]; then
        ws_match=''${BASH_REMATCH[1]}
      fi
    fi

    if [[ -z "$ws_match" ]]; then
      ws_match="default"
    fi
    note_path=$(zk new -p -g workspace --working-dir="$HOME/pkm" --extra=ws="$ws_match" --title="$title" "$note_root")

    # Append to daily note
    daily_note=$(zk new -p --no-input --title="$title" "$HOME/pkm/journal/daily")
    echo -e "\n[[dots/''${note_path##*/}]]" >> "$daily_note"
    
    ws_file="$HOME/pkm/workspace/$ws_match.md"
    zk new -p --no-input --working-dir="$HOME/pkm/workspace" --template="$HOME/.config/zk/templates/workspace-main.md" --extra=ws="$ws_match" --id="$ws_match" --title="$title" >/dev/null 2>&1
    echo -e "\n[[dots/''${note_path##*/}]]" >> "$ws_file"

    if [[ "$print_path" == "true" ]]; then
      echo "$note_path"
    else
      zk edit "$note_path"
    fi
  '';
}
