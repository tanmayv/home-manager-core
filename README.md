# Minimal Cloudtop Home Manager Config

This is a modern, AI-focused Home Manager configuration tailored for Googlers setting up a new Cloudtop. It bridges the gap between powerful CLI tools and an accessible, mouse-friendly terminal interface.

## Key Features

*   **Intelligent Workspace Navigation (Fig/CitC Aware)**:
    *   Lightning-fast `cd` wrapper using Zoxide that automatically syncs with your Fig workspaces.
    *   `hgd` wrapper that automatically switches your Tmux session when you change directories.
    *   (Both auto-switching behaviors are enabled by default but configurable via `setup.nix`).
*   **Mouse-Centric Tmux Experience**:
    *   Clickable session list in the status bar for instant context switching.
    *   Right-click context menus on sessions to create, rename, or kill them easily.
    *   Smart pane navigation (`Ctrl+h/j/k/l`) that seamlessly integrates with Vim, Neovim, Helix, and Lazygit.
*   **Command Palette (`Ctrl+p`)**:
    *   A searchable, LRU-ranked (Least Recently Used) command palette built with `fzf`.
    *   Quick access to window management, session switching, and reloading the configuration.
*   **AI Integration & Tooling**:
    *   Built-in "Chat with Gemini" and "Ask Duckie" commands right in the command palette.
    *   Coordination scripts (`iamdone`, `waiting`, `send-message-to-agent`) included to support autonomous multi-agent workflows.
*   **Interactive CodeSearch (`Ctrl+s`)**:
    *   Search the Google3 codebase directly from the terminal with a live, syntax-highlighted `bat` preview.
    *   Maintains search history and instantly opens the selected file relative to your workspace root.
*   **Modern Shell Essentials**:
    *   **Zsh** with the clean `Pure` prompt (customized to show your CitC workspace).
    *   **Zoxide** for smarter, fuzzy `cd` jumping.
    *   **Atuin** for magical, searchable shell history.
    *   **Mercurial (`hg`)** configured with `extdiff` (using Neovim) and standard `.hgignore` exclusions.

## Installation & Setup

1.  Clone this repository to `~/.config/minimal-cloudtop` on your Cloudtop.
2.  Open `setup.nix` and change `username = "tanmayvijay";` to your LDAP. You can also toggle specific features on or off in this file.
3.  Apply the configuration by running:

```bash
cd ~/.config/minimal-cloudtop
home-manager switch --flake ".#your-ldap"
```

## Updating Configuration

Once installed, you can easily tweak the configuration and apply changes without leaving your workflow:

1. Press `[CMDS]` in the Tmux status bar (or `Ctrl+p`).
2. Search for **"Edit Home-manager Configuration"** to open a file searcher in the config directory.
3. Search for **"Build and Switch"** to instantly rebuild and apply your changes.
