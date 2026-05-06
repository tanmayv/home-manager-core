# Skill: Home Manager Extension

Guide to creating, adding, and updating extensions in the Minimal Cloudtop environment.

## Overview

Extensions in Minimal Cloudtop are structured as independent Nix flakes that expose Home Manager modules. This allows for modular customization without modifying the base configuration.

## Style Guide

*   **Isolation**: Extensions should be self-contained in their own directory (e.g., `extensions/extension-name`).
*   **Modularity**: Use a separate `options.nix` to define customizable settings.
*   **Conventions**:
    *   Expose the main Home Manager module as `homeManagerModules.default` in `flake.nix`.
    *   Use `lib.mkOption` to provide defaults that can be overridden by the user.
    *   Prefix options with a logical domain (e.g., `services.my-extension`).

## Creating a New Extension

1.  Create a new directory under `extensions/`:
    ```bash
    mkdir -p extensions/my-extension
    ```

2.  Create a `flake.nix` in that directory:
    ```nix
    {
      description = "My Awesome Extension";
      inputs.nixpkgs.follows = "nixpkgs";
      outputs = { nixpkgs, ... }@inputs: {
        homeManagerModules.default = ./default.nix;
      };
    }
    ```

3.  Create `options.nix` to define your settings:
    ```nix
    { lib, ... }:
    with lib;
    {
      options.services.my-extension = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable my extension";
        };
      };
    }
    ```

4.  Create `default.nix` for the implementation:
    ```nix
    { pkgs, lib, config, ... }:
    with lib;
    let
      cfg = config.services.my-extension;
    in
    {
      imports = [ ./options.nix ];
      config = mkIf cfg.enable {
        home.packages = [ pkgs.my-favorite-tool ];
        # Add more Home Manager configuration here
      };
    }
    ```

## Adding to Root Flake

To use the extension, add it to the root `flake.nix`:

1.  Add to `inputs`:
    ```nix
    inputs = {
      # ...
      my-extension = {
        url = "path:./extensions/my-extension"; # Or a git URL
        inputs.nixpkgs.follows = "nixpkgs";
      };
    };
    ```

2.  Add to `outputs` in the `homeConfigurations.cloudtop` modules list:
    ```nix
    modules = [
      ./home.nix
      inputs.my-extension.homeManagerModules.default
      
      # Configure it
      ({ ... }: {
        services.my-extension.enable = true;
      })
    ];
    ```

## Adding Hotkeys and Command Palette

*   **Raw Hotkeys**: You can add raw tmux hotkeys directly in your extension's `default.nix` using `programs.tmux.extraConfig`.
*   **Command Palette**: Currently, to add commands to the palette, you must add them to `modules/tmux-palette.nix` in the `commands.toml` section (or wait for the planned JSON dynamic loading feature).

## Updating Extensions

*   If the extension is a local path (`path:./...`), changes are picked up automatically on the next `build-and-switch`.
*   If the extension is a remote git repository, run:
    ```bash
    nix flake lock --update-input my-extension
    ```
    Then run `build-and-switch`.
