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
     inherit username inputs userSettings; 
   };
   ```

3. Import the module in your `modules` list:
   ```nix
   modules = [ 
     minimal-cloudtop.homeManagerModules.default
     # ... your other modules
   ];
   ```

## Note on Arguments

The Minimal Cloudtop module expects `username` and `userSettings` to be available. Ensure these are defined and passed through `extraSpecialArgs` as shown in the example.
