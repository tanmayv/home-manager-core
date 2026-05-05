# Getting Started with Minimal Cloudtop

Follow these steps to transform your terminal into a powerful, AI-integrated workspace.

## 1. Prerequisites

### Internet Exception
Minimal Cloudtop requires an internet exception to download Nix packages and AI dependencies.
- Request an exception via the internal portal (search for **"Internet Exception"**).

### Install Nix
We use Nix for robust package management.
- Follow the guide at **go/nix** to install and configure Nix.
- **Verification**: Ensure `nix --version` works and you are in the `nix-users` group.

```bash
sudo apt install nix-setup-systemd
sudo tee -a /etc/nix/nix.conf <<< 'experimental-features = nix-command flakes'
```
- Logout and ssh into the cloudtop again.

```bash
sudo usermod -a -G nix-users $USER
nix-channel --add https://nixos.org/channels/nixpkgs-unstable && nix-channel --update nixpkgs
```


## 2. Installation as a Flake Input (Recommended)

The recommended way to use Minimal Cloudtop is to import it as a module into your personal dotfiles Flake. This keeps your personal configurations neatly separated from the upstream core logic.

### Create your Personal Flake
Create a new directory for your configuration and create a `flake.nix`:

```bash
mkdir -p ~/my-nix-config
cd ~/my-nix-config
```

Create a `flake.nix` with the following content, replacing `your-ldap` with your LDAP:

```nix
{
  description = "My personal Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    minimal-cloudtop = {
      url = "sso://user/tanmayvijay/home-manager-minimal-ai";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, minimal-cloudtop, ... }@inputs:
    let
      user = "your-ldap";
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      homeConfigurations."cloudtop" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { 
          inherit inputs; 
          userSettings = { 
            # Toggle features here
            enable-ai-workflow = true;
            enable-neovim = true;
            enable-tasks = true;
          };
        };
        modules = [ 
          minimal-cloudtop.homeManagerModules.default 
          ({ pkgs, ... }: {
            home.username = user;
            home.homeDirectory = "/usr/local/google/home/${user}";
          })
        ];
      };
    };
}
```

## 3. Initial Build

Apply the configuration for the first time:

```bash
nix run home-manager -- switch -b backup --flake ".#cloudtop"
```

*Note: After the initial successful build, you can use the `build-and-switch` command (or the Command Palette shortcut) to apply future updates.*

## 4. Verify Installation

Once the build finishes, restart your shell or start a new Tmux session:
- Your Zsh prompt should now show your CitC workspace (if applicable).
- Press `Ctrl+p` to open the Command Palette.
- Clickable session indicators should appear in the Tmux status bar.

---

## Alternative: Standalone Installation
If you prefer to not use your own Flake and would rather clone the configuration directly, you can check the legacy installation methods by looking at the `stable` branch documentation.

