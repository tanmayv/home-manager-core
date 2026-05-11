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
Create the Home Manager configuration directory:

```bash
mkdir -p ~/.config/home-manager
cd ~/.config/home-manager
```

Create a `setup.nix` to configure your features, replacing `your-ldap` with your LDAP:

```nix
{
  username = "your-ldap";
  config-location = "~/.config/home-manager";
  
  # Features
  enable-ai-workflow = true;
  enable-neovim = true;
  enable-tasks = true;
  enable-agent-tracker = true;
  enable-smart-cd = true;
}
```

Create a `flake.nix` with the following content:

```nix
{
  description = "User Home Manager configuration";

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

    extensions = {
      url = "sso://user/tanmayvijay/home-manager-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvim-nix = {
      url = "sso://user/tanmayvijay/nvim-nix";
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
      userSettings = import ./setup.nix;
      user = userSettings.username;
    in {
      homeConfigurations.cloudtop = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        extraSpecialArgs = { 
          inherit userSettings;
          inputs = inputs // minimal-cloudtop.inputs;
        };

        modules = [ 
          minimal-cloudtop.homeManagerModules.default
          extensions.homeManagerModules.google3-zsh
          extensions.homeManagerModules.google3-bash
          extensions.homeManagerModules.google-agents
          extensions.homeManagerModules.google-codesearch
          extensions.homeManagerModules.google3-tmux
          extensions.homeManagerModules.google3-ai
          extensions.homeManagerModules.google3-scripts
          extensions.homeManagerModules.google3-hg

          ({ ... }: {
            services.agent-tracker.enable = userSettings.enable-agent-tracker or false;
            services.agent-tracker.enableTmuxIntegration = true;
            
            programs.tmux.sessionizerSearchPaths = [ "/google/src/cloud/$USER" "~" ];
            programs.tmux.sessionizerDisplayReplacements = {
              "/google/src/cloud/$USER" = "[Fig]";
            };
            programs.tasks.workspaceSearchPaths = [ "/google/src/cloud/$USER" ];
          })

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

## Updating to New Stable Releases

Because your configuration is managed as a Nix Flake, updating to the latest stable release of Minimal Cloudtop and its extensions is straightforward:

1. **Navigate to your configuration directory**:
   ```bash
   cd ~/.config/home-manager
   ```

2. **Update the Flake inputs**:
   This will fetch the latest commits for all inputs (including `minimal-cloudtop` and `extensions` which are tracked to the rolling `stable` tag) and update your `flake.lock`:
   ```bash
   nix flake update
   ```

3. **Apply the updates**:
   Run the build command to apply the updated configuration:
   ```bash
   build-and-switch
   ```

---

## Alternative: Standalone Installation
If you prefer to not use your own Flake and would rather clone the configuration directly, you can check the legacy installation methods by looking at the `stable` branch documentation.

