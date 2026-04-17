# Minimal Home Manager Config for Cloudtop

This is a minimal Home Manager configuration tailored for Googlers setting up a new Cloudtop. It includes the essentials: `zsh`, `tmux`, `zoxide`, and `atuin`.

## How to use

1. Clone or copy this directory (`minimal-cloudtop`) to `~/.config/` on your Cloudtop.
2. Open `flake.nix` and change `username = "tanmayvijay";` to your LDAP.
3. Apply the configuration by running:

```bash
home-manager switch --flake .#minimal
```

## Included Tools

* **Zsh:** Configured with syntax highlighting and autosuggestions.
* **Tmux:** Configured with `vi` mode, mouse support, and a `Ctrl+B` prefix.
* **Zoxide:** A smarter `cd` command.
* **Atuin:** Magical shell history using a SQLite database.
* **Fzf & Ripgrep:** Included as useful shell utilities.
