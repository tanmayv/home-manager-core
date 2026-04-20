# Getting Started with Minimal Cloudtop

Follow these steps to set up your environment from scratch.

## 1. Prerequisites

### Internet Exception
Before you begin, ensure your Cloudtop has an internet exception. This is required to fetch Nix packages and other dependencies.
- Request an exception via the internal portal (search for "Internet Exception" or follow your team's specific guidance).

### Install Nix and Home Manager
We rely on Nix for package management and Home Manager for configuration.
- Follow the official Google guide at **go/nix** to install Nix.
- Ensure you follow the steps to set up **Home Manager** as well.

## 2. Repository Setup

### Clone the Configuration
Clone this repository to the expected location on your Cloudtop:

```bash
git clone sso://user/tanmayvijay/home-manager-minimal-ai ~/.config/minimal-cloudtop
cd ~/.config/minimal-cloudtop
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

## 3. Initial Build

Apply the configuration for the first time:

```bash
home-manager switch --flake ".#your-ldap-here"
```

*Note: After the initial successful build, you can use the `build-and-switch` command (or the Command Palette shortcut) to apply future updates.*

## 4. Verify Installation

Once the build finishes, restart your shell or start a new Tmux session:
- Your Zsh prompt should now show your CitC workspace (if applicable).
- Press `Ctrl+p` to open the Command Palette.
- Clickable session indicators should appear in the Tmux status bar.
