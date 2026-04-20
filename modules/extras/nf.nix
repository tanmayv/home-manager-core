{ pkgs, ... }:

pkgs.writeShellApplication {
  name = "nf";
  runtimeInputs = with pkgs; [
    zk
    coreutils
    bash
  ];

  text = ''
    cd "$HOME/pkm" || exit 1
    zk edit -i
  '';
}
