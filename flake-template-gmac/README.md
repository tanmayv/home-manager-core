# Minimal Cloudtop (macOS ARM Edition)

A starter Home Manager configuration tailored for Apple Silicon (`aarch64-darwin`) macOS laptops, featuring AI Agents, Tmux, Zsh, and Neovim.

## Installation

1. Initialize your configuration using this template:
```bash
mkdir -p ~/.config/home-manager
cd ~/.config/home-manager
nix flake init -t github:tanmayv/home-manager-core#gmac
```

2. Edit `~/.config/home-manager/setup.nix` to configure your `username`.

3. Build and switch to your new environment:
```bash
nix run home-manager -- switch -b backup --flake "~/.config/home-manager#core"
```
