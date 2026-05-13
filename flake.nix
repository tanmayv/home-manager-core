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

  outputs = inputs@{ nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      homeManagerModules.default = {
        imports = [ ./home.nix ];
        _module.args.inputs = inputs;
      };
      templates = {
        default = {
          path = ./flake-template;
          description = "Pure, standalone Home Manager starter configuration";
        };
      };
    };
}
