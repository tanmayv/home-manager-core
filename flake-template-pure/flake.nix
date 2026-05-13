{
  description = "Pure, non-Google Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Minimal Cloudtop Core Library
    minimal-cloudtop = {
      type = "git";
      url = "sso://user/tanmayvijay/home-manager-minimal-ai";
      ref = "refs/tags/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pure Neovim configuration (no Google3/Cloudtop overrides)
    nvim-pure = {
      type = "git";
      url = "sso://user/tanmayvijay/nvim-pure";
      ref = "refs/tags/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, minimal-cloudtop, nvim-pure, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      baseSettings = import ./setup.nix;
      userSettings = baseSettings // {
        enable-ai-workflow = true;
      };
    in {
      homeConfigurations.core = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        extraSpecialArgs = { 
          inherit userSettings;
          inputs = inputs // minimal-cloudtop.inputs;
        };

        modules = [ 
          minimal-cloudtop.homeManagerModules.default
          nvim-pure.homeManagerModules.default

          ({ pkgs, ... }: {
            home.username = userSettings.username or "your-username";
            home.homeDirectory = if pkgs.stdenv.isLinux then "/home/${userSettings.username or "your-username"}" else "/Users/${userSettings.username or "your-username"}";
            home.stateVersion = "25.11";
          })
        ];
      };
    };
}
