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
      
      # Define your username and settings here
      # You can also import them from a separate setup.nix file
      username = "your-username";
      userSettings = {
        inherit username;
        enable-ai-workflow = true;
        enable-agent-tracker = true;
        # Add other settings from setup.nix as needed
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
