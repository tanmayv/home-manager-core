{ pkgs, config, ... }:

{
  home.packages = [
    (import ./agent-wrapper-package.nix { inherit pkgs config; })
  ];
}
