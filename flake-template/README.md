# Using Minimal Cloudtop as a Library

This directory contains an example `flake.nix` for integrating Minimal Cloudtop into your own Home Manager configuration.

## Setup

1. Add Minimal Cloudtop as an input to your `flake.nix`:
   ```nix
   inputs.minimal-cloudtop.url = "github:tanmayvijay/minimal-cloudtop/stable";
   ```

2. Pass the required `extraSpecialArgs` to your `homeManagerConfiguration`:
   ```nix
   extraSpecialArgs = { 
     inherit inputs userSettings; 
   };
   ```

3. Import the module in your `modules` list and set `home.username`:
   ```nix
   modules = [ 
     minimal-cloudtop.homeManagerModules.default
     {
       home.username = "your-username";
       home.homeDirectory = "/usr/local/google/home/your-username";
     }
   ];
   ```

## Note on Arguments

The Minimal Cloudtop module expects `userSettings` to be available. The `username` is automatically picked up from `config.home.username`.
