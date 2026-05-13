{ pkgs, lib, config, userSettings, ... }:

{
  programs.git = {
    enable = lib.mkDefault true;
    ignores = [
      ".jetskicli"
    ];
  };
}
