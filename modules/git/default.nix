{ pkgs, lib, config, userSettings, ... }:

{
  home.file.".config/git/ignore".text = ''
    .jetskicli
  '';
}
