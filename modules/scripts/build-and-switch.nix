{ pkgs, ... }:

let
  build-and-switch = pkgs.writeScriptBin "build-and-switch" ''
    #!/usr/bin/env bash

    CONFIG_FILE="$HOME/.config/home-manager-minimal-ai/setup.nix"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Config file not found: $CONFIG_FILE"
        exit 1
    fi

    # Read values using nix eval
    config_location=$(nix eval --raw --file "$CONFIG_FILE" config-location)
    username=$(nix eval --raw --file "$CONFIG_FILE" username)

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
