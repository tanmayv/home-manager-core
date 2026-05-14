{
  description = "macOS ARM (Apple Silicon) Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    minimal-cloudtop = {
      url = "github:tanmayv/home-manager-core";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    public-extensions = {
      url = "github:tanmayv/home-manager-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.tasks-nvim.follows = "tasks-nvim";
      inputs.nvim-nix.follows = "nvim-nix";
    };

    nvim-nix = {
      url = "github:tanmayv/neovim-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tasks-nvim = {
      url = "github:tanmayv/tasks.nvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, minimal-cloudtop, public-extensions, nvim-nix, tasks-nvim, ... }@inputs:
    let
      baseSettings = import ./setup.nix;
      system = baseSettings.system or "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      enableAiAgents = true; # macOS launchd is now fully supported!

      userSettings = baseSettings // {
        enable-ai-workflow = true;
        enable-agent-tracker = (baseSettings.enable-agent-tracker or true) && enableAiAgents;
      };
    in {
      homeConfigurations.core = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        extraSpecialArgs = { 
          inherit userSettings;
          inputs = inputs // minimal-cloudtop.inputs // public-extensions.inputs // nvim-nix.inputs;
        };

        modules = [ 
          minimal-cloudtop.homeManagerModules.default
          public-extensions.homeManagerModules.tasks
          public-extensions.homeManagerModules.ai-agents
          ({ lib, pkgs, ... }: {
            services.agent-tracker.enable = lib.mkForce (userSettings.enable-agent-tracker or false);
            home.username = userSettings.username or "your-username";
            home.homeDirectory = "/Users/${userSettings.username or "your-username"}";
            home.stateVersion = "25.11";
          })
        ];
      };
    };
}
