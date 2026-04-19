{ pkgs, userSettings, ... }:

let
  build-and-switch = pkgs.writeScriptBin "build-and-switch" ''
    #!/usr/bin/env bash

    config_location="${userSettings.config-location}"
    username="${userSettings.username}"

    # Expand ~ if present
    config_location="''${config_location/#\~/$HOME}"

    echo "Switching to configuration at $config_location for user $username..."
    cd "$config_location" || exit 1
    home-manager switch --flake ".#$username"
  '';
in
{
  home.packages = [
    build-and-switch
  ];
}
