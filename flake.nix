{
  description = "Minimal Home Manager configuration for Cloudtop (Core)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    astronvim-template = {
      url = "github:AstroNvim/template";
      flake = false;
    };
  };

  outputs = inputs@{ nixpkgs, ... }: {
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
