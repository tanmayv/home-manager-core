# Pure Home Manager Starter Configuration

This is a minimal, user-agnostic starter configuration for Home Manager powered by `minimal-cloudtop` and `neovim-flake`. It is completely free of Google3/CitC/Piper specific extensions or overrides.

## Initialization

To initialize this template in a new configuration directory:

```bash
mkdir -p ~/.config/home-manager
cd ~/.config/home-manager
nix flake init -t github:tanmayv/home-manager-core
```

## Configuration

1. Open `setup.nix` and set your `username`.
2. Set `system` appropriately (for example, `aarch64-darwin` on Apple Silicon macOS).
3. Customize toggles and search paths as needed.

## Activation

```bash
nix run .#homeConfigurations.core.activationPackage
```
