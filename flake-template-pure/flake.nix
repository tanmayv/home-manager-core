{
  description = "Pure, standalone Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Minimal Cloudtop Core Library (GitHub)
    minimal-cloudtop = {
      url = "github:tanmayv/home-manager-core";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Public Extensions (provides tasks, ai-agents, and inherits neovim-flake)
    extensions = {
      url = "github:tanmayv/home-manager-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, minimal-cloudtop, extensions, ... }@inputs:
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

        # Pass minimal-cloudtop and extensions inputs (which includes nvim-nix)
        extraSpecialArgs = { 
          inherit userSettings;
          inputs = inputs // minimal-cloudtop.inputs // extensions.inputs;
        };

        modules = [ 
          minimal-cloudtop.homeManagerModules.default
          extensions.homeManagerModules.tasks
          extensions.homeManagerModules.ai-agents
          extensions.inputs.nvim-nix.homeManagerModules.default

          ({ pkgs, ... }: {
            home.username = userSettings.username or "your-username";
            home.homeDirectory = if pkgs.stdenv.isLinux then "/home/${userSettings.username or "your-username"}" else "/Users/${userSettings.username or "your-username"}";
            home.stateVersion = "25.11";
          })
        ];
      };
    };
}
