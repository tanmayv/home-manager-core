# Getting Started with Minimal Cloudtop

Follow these steps to set up your environment from scratch.

## 1. Prerequisites

### Internet Exception
Before you begin, ensure your Cloudtop has an internet exception. This is required to fetch Nix packages and other dependencies.
- Request an exception via the internal portal (search for "Internet Exception" or follow your team's specific guidance).

### Install Nix and Home Manager
We rely on Nix for package management and Home Manager for configuration.
- Follow the official Google guide at **go/nix** to install Nix.
  - You need to ensure that nix binary is avaiable and you are part of nix-users group
  - (Optional: Setup channels)


## 2. Repository Setup

### Clone the Configuration
Clone this repository to the expected location on your Cloudtop:

```bash
git clone -b stable --single-branch sso://user/tanmayvijay/home-manager-minimal-ai ~/.config/minimal-cloudtop
cd ~/.config/minimal-cloudtop
```

### Create Your Personal Branch (Important!)
Before editing configuration files, create a personal branch. This allows the automatic updater to seamlessly rebase your customizations over new stable releases without conflicts.

```bash
git checkout -b my-config
```

### Personalize your Configuration
Open `setup.nix` and update the `username` to match your LDAP:

```nix
# setup.nix
{
  username = "your-ldap-here";
  # ... other settings
}
```

Commit your changes:
```bash
git commit -am "chore: personalize setup.nix"
```

*For a full list of configuration options and feature toggles, please see the [Customization Guide](Customization.md).*

## 3. Initial Build

Apply the configuration for the first time:

```bash
nix run home-manager -- switch --backup backup --flake ".#your-ldap-here"
```

*Note: After the initial successful build, you can use the `build-and-switch` command (or the Command Palette shortcut) to apply future updates.*

## 4. Verify Installation

Once the build finishes, restart your shell or start a new Tmux session:
- Your Zsh prompt should now show your CitC workspace (if applicable).
- Press `Ctrl+p` to open the Command Palette.
- Clickable session indicators should appear in the Tmux status bar.
