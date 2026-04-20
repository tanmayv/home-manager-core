{ pkgs, ... }:

pkgs.writeShellApplication {
  name = "nd"; # I'll use 'nd' directly as the name since it's the alias the user uses
  runtimeInputs = with pkgs; [
    zk
    coreutils
    bash
  ];

  text = ''
    pkm_root="$HOME/pkm"
    note_path=$(zk new --no-input -p "$pkm_root/journal/daily")
    zk edit "$note_path"
  '';
}
