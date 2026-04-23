{ pkgs, ... }:
let
  palette = import ../palette.nix;
  
  # Helper to convert hex #RRGGBB to "R;G;B" for escape sequences
  hexToRgb = hex: 
    let
      # Mapping for hex to decimal
      m = { "0"=0;"1"=1;"2"=2;"3"=3;"4"=4;"5"=5;"6"=6;"7"=7;"8"=8;"9"=9;"a"=10;"b"=11;"c"=12;"d"=13;"e"=14;"f"=15;"A"=10;"B"=11;"C"=12;"D"=13;"E"=14;"F"=15; };
      h = builtins.substring 1 6 hex;
      # Convert 2-digit hex to decimal
      dec = s: (m.${builtins.substring 0 1 s} * 16) + m.${builtins.substring 1 1 s};
      r = dec (builtins.substring 0 2 h);
      g = dec (builtins.substring 2 2 h);
      b = dec (builtins.substring 4 2 h);
    in "${toString r};${toString g};${toString b}";

  # Dynamically derive RGB strings from palette
  rgb = {
    color1 = hexToRgb palette.color1; # User
    color2 = hexToRgb palette.color2; # CitC client
    color3 = hexToRgb palette.color3; # Path
    color4 = hexToRgb palette.color4; # Host
  };

in
{
  programs.bash.initExtra = ''
    # Installs a cool, dynamic, Google-colored prompt.

    citc_client() {
      CITC_BASE="/google/src/cloud/$USER"
      [[ `pwd` =~ ^$CITC_BASE/([^/]*).* ]] && echo ''${BASH_REMATCH[1]}
    }
    citc_separator() {
      [ $(citc_client) ] && echo ':'
    }
    g3pwd() {
      CITC_BASE="/google/src/cloud/$USER"
      # Get CitC client name based on current path
      if [[ $PWD =~ ^"$HOME"(/|$) ]]; then
        echo "~''${PWD#$HOME}"
      else
        G3PWD=$PWD
        CITC_CLIENT=$(citc_client)
        CITC_PATH=$CITC_BASE/$CITC_CLIENT

        # Remove CitC client path
        G3PWD=$(echo -n $G3PWD | sed -e "s:$CITC_PATH::")

        # Collapse /google3$ or /google/ to //
        G3PWD=$(echo -n $G3PWD | sed -e "s:^/google3\(/\|$\)://:")

        # Abbreviate //j/c/g paths
        G3PWD=$(echo -n $G3PWD | sed -e "s:^//java/com/google://j/c/g:")

        # Abbreviate //jt/c/g paths
        G3PWD=$(echo -n $G3PWD | sed -e "s:^//javatests/com/google://jt/c/g:")

        echo $G3PWD
      fi
    }

    # Colors using TrueColor escape sequences derived dynamically from palette.nix
    NO_COLOR="\[\e[0m\]"
    RED="\[\e[38;2;${rgb.color1}m\]"
    GREEN="\[\e[38;2;${rgb.color2}m\]"
    YELLOW="\[\e[38;2;${rgb.color3}m\]"
    BLUE="\[\e[38;2;${rgb.color4}m\]"

    PS1="\
''${debian_chroot:+($debian_chroot)}\
$RED\u\
$NO_COLOR@\
$BLUE\h\
$NO_COLOR:\
$GREEN\$(citc_client)\
$NO_COLOR\$(citc_separator)\
$YELLOW\$(g3pwd)\
$NO_COLOR\\$ "
  '';
}
