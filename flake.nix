{
  description = "Minimal Home Manager configuration for Cloudtop";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix.url = "github:danth/stylix";
    astronvim-template = {
      url = "github:AstroNvim/template";
      flake = false;
    };
  };

  outputs = { nixpkgs, home-manager, stylix, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      userSettings = import ./setup.nix;
      username = userSettings.username;
    in {
      homeConfigurations."${username}" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit username inputs userSettings; };
        modules = [ 
          stylix.homeModules.stylix
          ./home.nix 
        ];
      };
    };
}
