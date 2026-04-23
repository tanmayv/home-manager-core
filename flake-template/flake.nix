{
  description = "Example flake using minimal-cloudtop as a library";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Use the stable version of minimal-cloudtop
    minimal-cloudtop = {
      type = "git";
      url = "sso://user/tanmayvijay/home-manager-minimal-ai";
      ref = "refs/tags/stable";
    };
  };

  outputs = { nixpkgs, home-manager, minimal-cloudtop, ... }@inputs:
    let
      system = "x86_64-linux";
      # 2. Option B: Import from a local setup.nix and optionally override values
      baseSettings = import ./setup.nix;

      # You can override any setting from setup.nix here
      userSettings = baseSettings // {
        # Add Overrides here
        enable-ai-workflow = true; 
        # enable-agent-tracker = false;
      };
      in {
      # The configuration name (e.g. .#cloudtop)
      homeConfigurations.cloudtop = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # minimal-cloudtop Home Manager module requires userSettings
        extraSpecialArgs = { 
          inherit inputs userSettings; 
        };

        modules = [ 
          # Import the minimal-cloudtop Home Manager module
          minimal-cloudtop.homeManagerModules.default

          # Your own Home Manager configuration
          ({ pkgs, ... }: {
            # Set your username here. Minimal Cloudtop will pick it up!
            home.username = "your-username";
            home.homeDirectory = "/usr/local/google/home/your-username";
            home.stateVersion = "23.11";

            # Additional configuration...
          })
        ];
      };
      };
    };
}
