{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "nmn";
  runtimeInputs = with pkgs; [
    zk
    coreutils
    bash
    fzf
  ];

  text = ''
    print_path=false
    title=""

    while [[ "$#" -gt 0 ]]; do
      case "$1" in
        --print-path)
          print_path=true
          shift
          ;;
        -t)
          title="$2"
          shift 2
          ;;
        -t*)
          title="''${1#*-t}"
          shift
          ;;
        *)
          break
          ;;
      esac
    done

    meeting_dir="$HOME/pkm/meetings"

    if [[ -z "$title" ]]; then
      title=$(find "$meeting_dir" -maxdepth 1 -name "*.md" -printf "%f\n" | sed 's/\.md$//' | fzf --prompt="Select meeting note: ")
    fi

    if [[ -z "$title" ]]; then
      echo "No title selected or provided"
      exit 1
    fi

    meeting_note=$(zk new -p --no-input --working-dir="$meeting_dir" --title "$title")

    pkm_dir="$HOME/pkm"

    current_datetime=$(TZ=Asia/Kolkata date "+%Y-%m-%d %H:%M")
    current_date=$(TZ=Asia/Kolkata date "+%Y-%m-%d")

    note_path=$(nn --print-path --title="$title - $current_date")

    relative_path="''${note_path#"$pkm_dir"/}"
    relative_path_noext="''${relative_path%.md}"


    echo -e "\n- $current_datetime [[''${relative_path_noext}]]" >> "$meeting_note"

    if [[ "$print_path" == "true" ]]; then
      echo "$note_path"
    else
      zk edit "$note_path"
    fi
  '';
}
