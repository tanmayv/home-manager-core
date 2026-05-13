# Getting Started with Minimal Cloudtop

Follow these steps to transform your terminal into a powerful, AI-integrated workspace.

## 1. Prerequisites

### Internet Exception
Minimal Cloudtop requires an internet exception to download Nix packages and AI dependencies.
- Request an exception via the internal portal (search for **"Internet Exception"**).

### Install Nix
We use Nix for robust package management.
- Follow the guide at **go/nix** to install and configure Nix.
- **Verification**: Ensure `nix --version` works, you are in the `nix-users` group, and your user is trusted by the Nix daemon.

```bash
# Install Nix daemon in gLinux
sudo apt install nix-setup-systemd

# Enable Flakes and configure Trusted Users to allow binary caches (e.g. Neovim Nightly)
sudo tee -a /etc/nix/nix.conf <<< 'experimental-features = nix-command flakes'
sudo tee -a /etc/nix/nix.conf <<< 'trusted-users = root @nix-users'

# Add yourself to the nix-users group
sudo usermod -a -G nix-users $USER
```

- **CRITICAL**: You must **logout and ssh into your cloudtop again** (or restart your terminal session) to apply the group membership.
- After logging back in, restart the Nix daemon to pick up the updated configuration:
```bash
sudo systemctl restart nix-daemon
```

- Update Nix channels:
```bash
nix-channel --add https://nixos.org/channels/nixpkgs-unstable && nix-channel --update nixpkgs
```


## 2. Installation as a Flake Input (Recommended)

The recommended way to use Minimal Cloudtop is to bootstrap a starter configuration using Flake templates. This keeps your personal configurations neatly separated from the upstream core logic.

### Initialize Starter Configuration
Create the Home Manager configuration directory and initialize the Google3 template:

```bash
mkdir -p ~/.config/home-manager
cd ~/.config/home-manager
nix flake init -t github:tanmayv/home-manager-core#default
```

### Customize Settings
Open `setup.nix` and replace `your-username` with your actual LDAP username:

```nix
{
  username = "your-ldap";
  config-location = "~/.config/home-manager";
  
  # Customize features as needed...
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

