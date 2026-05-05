{
  description = "Minimal Home Manager configuration for Cloudtop";

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
      type = "git";
      url = "sso://user/tanmayvijay/nvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tasks-nvim = {
      url = "github:tanmayv/tasks.nvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }@inputs:
    let
      user = "tanmayvijay";
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      userSettings = import ./setup.nix;
    in {
      homeConfigurations = rec {
        cloudtop = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit inputs userSettings; };
          modules = [ 
            ./home.nix 

            # Temporary override for local build
            ({ pkgs, ... }: {
              home.username = user;
              home.homeDirectory = "/usr/local/google/home/${user}";
            })
          ];
        };

        # Expose the configuration under the specific user's name as well
        "${user}" = cloudtop;
      };

      homeManagerModules.default = ./home.nix;
    };
}
