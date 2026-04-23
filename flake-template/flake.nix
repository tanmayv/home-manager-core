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
    };
  };

  outputs = { nixpkgs, home-manager, minimal-cloudtop, ... }@inputs:
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
          inherit inputs userSettings; 
        };

        modules = [ 
          # Import the minimal-cloudtop Home Manager module
          minimal-cloudtop.homeManagerModules.default

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
