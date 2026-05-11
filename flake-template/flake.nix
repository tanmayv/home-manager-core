{
  description = "Example flake using minimal-cloudtop as a library";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Use the stable version of minimal-cloudtop
    minimal-cloudtop = {
      type = "git";
      url = "sso://user/tanmayvijay/home-manager-minimal-ai";
      ref = "refs/tags/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Google-specific extensions
    extensions = {
      type = "git";
      url = "sso://user/tanmayvijay/home-manager-extensions";
      ref = "refs/tags/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvim-nix = {
      type = "git";
      url = "sso://user/tanmayvijay/nvim-nix";
      ref = "refs/tags/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    tasks-nvim = {
      url = "github:tanmayv/tasks.nvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, minimal-cloudtop, extensions, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Import from a local setup.nix and optionally override values
      # Note: Ensure setup.nix exists in the same directory!
      baseSettings = import ./setup.nix;

      # You can override any setting from setup.nix here
      userSettings = baseSettings // {
        # Add Overrides here, look at setup.nix for available options.
        enable-ai-workflow = true; 
        # enable-agent-tracker = false;
      };
    in {
      # The configuration name (e.g. .#cloudtop)
      homeConfigurations.cloudtop = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # minimal-cloudtop Home Manager module requires userSettings and inputs
        extraSpecialArgs = { 
          inherit userSettings;
          inputs = inputs // minimal-cloudtop.inputs;
        };

        modules = [ 
          # Import the minimal-cloudtop Home Manager module
          minimal-cloudtop.homeManagerModules.default

          # Load Google-specific extensions
          extensions.homeManagerModules.google3-zsh
          extensions.homeManagerModules.google3-bash
          extensions.homeManagerModules.google-agents
          extensions.homeManagerModules.google-codesearch
          extensions.homeManagerModules.google3-tmux
          extensions.homeManagerModules.google3-ai
          extensions.homeManagerModules.google3-scripts
          extensions.homeManagerModules.google3-hg

          # Configure extension options
          ({ ... }: {
            services.agent-tracker.enable = userSettings.enable-agent-tracker or false;
            services.agent-tracker.enableTmuxIntegration = true;
            
            programs.tmux.sessionizerSearchPaths = [ "/google/src/cloud/$USER" "~" ];
            programs.tmux.sessionizerDisplayReplacements = {
              "/google/src/cloud/$USER" = "[Fig]";
            };
            programs.tasks.workspaceSearchPaths = [ "/google/src/cloud/$USER" ];
          })

          # Your own configuration block
          ({ pkgs, ... }: {
            # IMPORTANT: Set your LDAP/username here!
            home.username = "your-username";
            home.homeDirectory = "/usr/local/google/home/your-username";
            home.stateVersion = "25.11";
            
            # Add your own Home Manager configuration here...
          })
        ];
      };
    };
}
