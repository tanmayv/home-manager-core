# Minimal Cloudtop Home Manager Config

This is a modern, AI-focused Home Manager configuration tailored for Googlers setting up a new Cloudtop. It bridges the gap between powerful CLI tools and an accessible, mouse-friendly terminal interface.

## Key Features

*   **AI Agent Orchestration & Communication**:
    *   **Inter-Agent Protocol**: Integrated tools (`send-message-to-agent`, `waiting`, `iamdone`) allow AI agents in different tmux panes to coordinate, share data via `/tmp`, and signal completion.
    *   **Agent Identity**: Clear visual identification in tmux pane borders showing `[Pane ID] | [Agent Name] | [Current Title]`.
    *   **Context-Aware Queries**: Automated tools to capture active pane context and pass it to AI agents for smarter assistance.
    *   **Agent Knowledge Management**: Dedicated directory for persistent markdown notes, accessible via the Command Palette for quick reading and writing.
*   **Intelligent Workspace Navigation (Fig/CitC Aware)**:
    *   Lightning-fast `cd` wrapper using Zoxide that automatically syncs with your Fig workspaces.
    *   `hgd` wrapper that automatically switches your Tmux session when you change directories.
*   **Mouse-Centric Tmux Experience**:
    *   Clickable session list in the status bar for instant context switching.
    *   Right-click context menus on sessions to create, rename, or kill them easily.
    *   Smart pane navigation (`Ctrl+h/j/k/l`) that seamlessly integrates with Vim, Neovim, Helix, and Lazygit.
*   **Command Palette (`Ctrl+p`)**:
    *   A searchable, LRU-ranked (Least Recently Used) command palette built with `fzf`.
    *   Quick access to window management, session switching, and workflow tools.
*   **Interactive CodeSearch (`Ctrl+s`)**:
    *   Search the Google3 codebase directly from the terminal with a live, syntax-highlighted `bat` preview.
    *   Maintains search history and instantly opens the selected file relative to your workspace root.
*   **Modern Shell Essentials**:
    *   **Zsh** with the clean `Pure` prompt (customized to show your CitC workspace).
    *   **Zoxide** for smarter, fuzzy `cd` jumping.
    *   **Atuin** for magical, searchable shell history.
    *   **Mercurial (`hg`)** configured with `extdiff` (using Neovim) and standard `.hgignore` exclusions.
*   **Tokyo Night Theming**: Unified color palette across all tools for a consistent, high-contrast aesthetic.

## Installation & Setup

1.  Clone this repository to `~/.config/minimal-cloudtop` on your Cloudtop.
2.  Open `setup.nix` and change `username = "tanmayvijay";` to your LDAP. You can also toggle specific AI features in the `ai_features` block.
3.  Apply the configuration by running:

```bash
cd ~/.config/minimal-cloudtop
build-and-switch
```

## Updating Configuration

Once installed, you can easily tweak the configuration and apply changes without leaving your workflow:

1. Press `[CMDS]` in the Tmux status bar (or `Ctrl+p`).
2. Search for **"Edit Home-manager Configuration"** to open a file searcher in the config directory.
3. Search for **"Build and Switch"** to instantly rebuild and apply your changes.
