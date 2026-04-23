{
  description = "Example flake using minimal-cloudtop as a library";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Use the stable version of minimal-cloudtop
    minimal-cloudtop.url = "github:tanmayvijay/minimal-cloudtop/stable";
  };

  outputs = { nixpkgs, home-manager, minimal-cloudtop, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      
      # 1. Option A: Define settings directly in the flake
      # username = "your-username";
      # userSettings = { inherit username; enable-ai-workflow = true; };

      # 2. Option B: Import from a local setup.nix and optionally override values
      baseSettings = import ./setup.nix;
      username = baseSettings.username;
      
      # You can override any setting from setup.nix here
      userSettings = baseSettings // {
        enable-ai-workflow = true; 
        # enable-agent-tracker = false;
      };
    in {
      homeConfigurations."${username}" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        
        # minimal-cloudtop expects these arguments to be passed
        extraSpecialArgs = { 
          inherit username inputs userSettings; 
        };
        
        modules = [ 
          # Import the minimal-cloudtop Home Manager module
          minimal-cloudtop.homeManagerModules.default
          
          # Your own Home Manager configuration
          ({ pkgs, ... }: {
            home.username = username;
            home.homeDirectory = "/usr/local/google/home/${username}";
            home.stateVersion = "23.11";
            
            # Additional configuration...
          })
        ];
      };
    };
}
