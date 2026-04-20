{ pkgs, username, ... }:
let
  nn = import ./nn.nix { inherit pkgs username; };
  nmn = import ./nmn.nix { inherit pkgs; };
  tmux-notes-window = import ./tmux-notes-window.nix { inherit pkgs; };
  nd = import ./nd.nix { inherit pkgs; };
  nf = import ./nf.nix { inherit pkgs; };
  wn = import ./wn.nix { inherit pkgs; };
in
{
  home.packages = with pkgs; [
    zk
    bat
    nn
    nmn
    tmux-notes-window
    nd
    nf
    wn
  ];

  home.shellAliases = {
    wn = "wn";
    nf = "nf";
    nd = "nd";
    nn = "nn";
    nmn = "nmn";
  };

  xdg.configFile."zk" = {
    source = ./dotfiles/zk;
    recursive = true;
  };
}
