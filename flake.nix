{
  description = "Minimal Home Manager configuration for Cloudtop (Core)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    broccoli-comms = {
      url = "github:tanmayv/broccoli-comms";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    astronvim-template = {
      url = "github:AstroNvim/template";
      flake = false;
    };
  };

  outputs = inputs@{ nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
    in {
      packages = forAllSystems (system: pkgs: {
        agent-communicator = inputs.broccoli-comms.packages.${system}.agent-communicator;
        default = inputs.broccoli-comms.packages.${system}.agent-communicator;
      });

      homeManagerModules.default = {
        imports = [ ./home.nix ];
        _module.args.inputs = inputs;
      };
      templates = {
        default = {
          path = ./flake-template;
          description = "Pure, standalone Home Manager starter configuration";
        };
        gmac = {
          path = ./flake-template-gmac;
          description = "macOS ARM (Apple Silicon) Home Manager starter configuration with AI Agents and Neovim";
        };
      };
    };
}
