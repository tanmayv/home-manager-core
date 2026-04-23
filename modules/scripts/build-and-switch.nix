{ pkgs, config, userSettings, ... }:

let
  build-and-switch = pkgs.writeScriptBin "build-and-switch" ''
    #!/usr/bin/env bash

    config_location="${userSettings.config-location}"

    # Expand ~ if present
    config_location="''${config_location/#\~/$HOME}"

    echo "Switching to configuration at $config_location..."
    cd "$config_location" || exit 1
    home-manager switch --flake ".#cloudtop"
  '';
in
{
  home.packages = [
    build-and-switch
  ];
}
