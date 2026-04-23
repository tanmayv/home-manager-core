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


## 2. Repository Setup

### Clone the Configuration
Clone the repository to the standard configuration path. We recommend starting with the `stable` branch:

```bash
git clone -b stable --single-branch sso://user/tanmayvijay/home-manager-minimal-ai ~/minimal-cloudtop
cd ~/.config/minimal-cloudtop
```

### Create Your Personal Branch (CRITICAL)
**Do not skip this step.** Creating a personal branch allows the system to update the core logic while preserving your personal settings in `setup.nix`.

```bash
git checkout -b my-config
```

### Personalize `setup.nix`
Open `setup.nix` and update the `username` to your LDAP. You can also toggle features like Neovim or AI orchestration here.

```nix
# setup.nix
{
  username = "your-ldap";
  # Explore other feature toggles below!
}
```

Commit your initial configuration:
```bash
git commit -am "chore: initial setup.nix personalization"
```

*For a full list of configuration options and feature toggles, please see the [Customization Guide](Customization.md).*

## 3. Initial Build

Apply the configuration for the first time:

```bash
nix run home-manager -- switch -b backup --flake ".#your-ldap-here"
```

*Note: After the initial successful build, you can use the `build-and-switch` command (or the Command Palette shortcut) to apply future updates.*

## 4. Verify Installation

Once the build finishes, restart your shell or start a new Tmux session:
- Your Zsh prompt should now show your CitC workspace (if applicable).
- Press `Ctrl+p` to open the Command Palette.
- Clickable session indicators should appear in the Tmux status bar.

---

## 5. Updating the Configuration

This repository is actively maintained. When a new stable version is released, you can easily pull the updates without losing your personal settings in `setup.nix`.

### Automatic Update Checks
Every time you start a new shell, a background check (`check-for-update`) runs once per day.
- If a new version is available, you will be prompted: `🎉 A new stable version of Minimal Cloudtop is available! Would you like to update now? [y/N]`
- If you select `y`, the tool will automatically fetch the latest `stable` tag, **rebase** your personal branch onto it, and run `build-and-switch`.

### Manual Update
If you want to trigger an update check manually, simply run:
```bash
check-for-update
```

Alternatively, you can perform a manual Git update:
```bash
# 1. Fetch the latest stable tag
git fetch origin tag stable --no-tags

# 2. Rebase your current branch onto the new stable version
git rebase origin/stable

# 3. Apply the changes
build-and-switch
```

*Note: If a rebase conflict occurs (rare if you only edit `setup.nix`), resolve the conflicts manually and then run `build-and-switch` to complete the update.*

---

## 6. Advanced: Using as a Library

If you already have an existing Nix Flake for your Home Manager configuration, you can use Minimal Cloudtop as a library/module instead of cloning the whole repository.

### Add Flake Input
In your `flake.nix`, add this repository as an input:

```nix
inputs.minimal-cloudtop = {
  type = "git";
  url = "sso://user/tanmayvijay/minimal-cloudtop";
  ref = "stable";
};
```

### Configure Module
1.  **Arguments**: Minimal Cloudtop requires `username` and `userSettings` to be passed via `extraSpecialArgs`.
2.  **Import**: Add the exported module to your `modules` list.

```nix
outputs = { nixpkgs, home-manager, minimal-cloudtop, ... }@inputs: {
  homeConfigurations."your-user" = home-manager.lib.homeManagerConfiguration {
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    extraSpecialArgs = { 
      inherit username inputs; 
      userSettings = { 
        inherit username; 
        enable-ai-workflow = true; # ... other settings
      };
    };
    modules = [ 
      minimal-cloudtop.homeManagerModules.default 
      # ... your existing modules
    ];
  };
};
```

*For a complete example, see the `flake-template/` directory in this repository.*
