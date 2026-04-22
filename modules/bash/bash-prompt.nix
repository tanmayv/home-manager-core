{ pkgs, ... }:
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

    # Colors using tput
    NO_COLOR="\[$(${pkgs.ncurses}/bin/tput sgr0)\]"
    RED="\[$(${pkgs.ncurses}/bin/tput setaf 1)\]"
    GREEN="\[$(${pkgs.ncurses}/bin/tput setaf 2)\]"
    YELLOW="\[$(${pkgs.ncurses}/bin/tput setaf 3)\]"
    BLUE="\[$(${pkgs.ncurses}/bin/tput setaf 4)\]"

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
