{
  description = "Minimal Home Manager configuration for Cloudtop (Core)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    astronvim-template = {
      url = "github:AstroNvim/template";
      flake = false;
    };

    nvim-nix = {
      url = "path:/usr/local/google/home/tanmayvijay/nvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tasks-nvim = {
      url = "github:tanmayv/tasks.nvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      homeManagerModules.default = ./home.nix;
    };
}
