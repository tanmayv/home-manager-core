{
  description = "Minimal Home Manager configuration for Cloudtop";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    minimal-cloudtop = {
      type = "git";
      url = "sso://user/tanmayvijay/home-manager-minimal-ai";
      ref = "refs/tags/stable";
    };

    astronvim-template = {
      url = "github:AstroNvim/template";
      flake = false;
    };
  };

  outputs = { nixpkgs, home-manager, minimal-cloudtop, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      userSettings = import ./setup.nix;
    in {
      homeConfigurations = {
        cloudtop = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit inputs userSettings; };
          modules = [ 
            # Use the Home Manager module from the Git input
            minimal-cloudtop.homeManagerModules.default

            # Define your user identity here
            ({ pkgs, ... }: {
              home.username = "your-ldap";
              home.homeDirectory = "/usr/local/google/home/your-ldap";
            })
          ];
        };
      };

      # Export the local home.nix as the module source
      homeManagerModules.default = ./home.nix;
    };
}
