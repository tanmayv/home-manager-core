# Customizing Your Configuration

All user-specific customization is centralized in `setup.nix`. After making changes to this file, you must apply them using the `build-and-switch` command.

## Applying Changes

1.  Open `setup.nix` in your editor.
2.  Modify the desired values or flags.
3.  Save the file.
4.  Run `build-and-switch` in your terminal (or use the Command Palette shortcut).

---

## Configuration Options

### Core Settings

| Option | Description | Default |
| :--- | :--- | :--- |
| `username` | Your Google LDAP. Sets home path and prompt context. | `"tanmayvijay"` |
| `config-location` | Path where this repo is cloned. | `"~/.config/minimal-cloudtop"` |
| `local_agent_knowledge_dir` | Path where agent markdown notes are stored. | `"~/agent_knowledge"` |
| `local_agent_knowledge_create_command` | Optional command override for creating new notes. | `""` |
| `editor` | The default CLI editor used by all system tools. | `"nvim"` |

### Feature Toggles

| Flag | Behavior if `true` | Behavior if `false` |
| :--- | :--- | :--- |
| `enable-ai-workflow` | Loads agents, skills, and inter-agent communication tools. | Disables all AI-specific logic and scripts. |
| `enable-neovim` | Loads custom Neovim config with plugins and keybindings. | Uses the default system Neovim without custom setup. |
| `enable-tmux-on-ssh` | Automatically starts/attaches tmux on SSH login (non-Cider). | Standard shell login without automatic tmux. |
| `auto-switch-workspace-on-cd` | Automatically switches tmux session when `cd`-ing into a workspace. | Standard `cd` behavior; sessions stay unchanged. |
| `auto-switch-workspace-on-hgd` | `hgd` command triggers an automatic tmux session switch. | `hgd` changes directory but doesn't switch sessions. |

### AI Features (`ai_features` block)

| Flag | Behavior if `true` | Behavior if `false` |
| :--- | :--- | :--- |
| `enable_ai_ssa_creator_skill` | Links the `ai-ssa-creator` skill to `~/.gemini/skills/`. | The skill is unavailable to agents. |
| `enable_tmux_based_agent_comms` | Installs `iamdone`, `waiting`, `send-message-to-agent` and communication skills. | Inter-agent communication tools are not installed. |

---

## Advanced Customization

### Adding Custom Nix Modules
If you want to add entirely new Nix modules:
1.  Place your `.nix` file in the `modules/` directory.
2.  Import it in `home.nix`.
3.  Rerun `build-and-switch`.

### Adding Command Palette Shortcuts
To add new commands to the `Ctrl+p` palette:
1.  Open `modules/tmux-palette.nix`.
2.  Add a new block to the `[[commands]]` list in the `home.file.".config/tmux-palette/commands.toml".text` section.
3.  Rerun `build-and-switch`.
