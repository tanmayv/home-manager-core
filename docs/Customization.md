# Customizing Your Configuration

All user-specific customization is centralized in `setup.nix`. Because this configuration is version-controlled by Git, modifying tracked files locally requires a strategy to avoid merge conflicts when pulling new updates.

## Managing Customizations (Two Strategies)

### Strategy 1: The "Personal Branch & Rebase" Workflow (Recommended)
This is the simplest method and is integrated directly into the `GettingStarted.md` guide.

1. **Setup**: After cloning the repository, immediately create your own branch (e.g., `git checkout -b my-config`).
2. **Customize**: Edit `setup.nix` and commit your changes to your `my-config` branch.
3. **Updating**: When the automatic updater detects a new `stable` release, it will prompt you. If you accept, it will automatically fetch the latest `stable` version and **rebase** your `my-config` commits on top of it. This seamlessly applies your custom settings over the new update.

### Strategy 2: The "Flake Input" Architecture (Advanced)
This is the most robust, update-proof method, but requires understanding Nix Flakes. Instead of editing this repository directly, you create a new, separate repository for your configuration and import this one as a library.

In your personal `flake.nix`, import minimal-cloudtop as an input:
```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    # Import minimal-cloudtop as a module
    minimal-cloudtop.url = "git+sso://user/tanmayvijay/home-manager-minimal-ai?ref=stable";
  };

  outputs = { self, nixpkgs, home-manager, minimal-cloudtop, ... }: {
    homeConfigurations."your-ldap" = home-manager.lib.homeManagerConfiguration {
      modules = [
        # Load all base configurations
        minimal-cloudtop.homeModules.default 
        
        # Your personal overrides
        ({ config, pkgs, ... }: {
           setup.username = "your-ldap";
           # Add your own packages or override settings here
        })
      ];
    };
  };
}
```
To update, simply run `nix flake update` in your personal repository.

---

## Applying Changes Locally

1.  Open `setup.nix` in your editor.
2.  Modify the desired values or flags.
3.  Save the file.
4.  Run `build-and-switch` in your terminal (or use the Command Palette shortcut).

---

## Configuration Options

> **Important Rule for Contributors/Agents:** If you add a new configuration flag or setting to `setup.nix`, you **must** document it in this file. Provide a clear description, its default value, and its behavior when toggled.

### Core Settings

| Option | Description | Default |
| :--- | :--- | :--- |
| `username` | Your Google LDAP. Sets home path and prompt context. | `"tanmayvijay"` |
| `config-location` | Path where this repo is cloned. | `"~/.config/minimal-cloudtop"` |
| `local_agent_knowledge_dir` | Path where agent markdown notes are stored. | `"~/agent_knowledge"` |
| `local_agent_knowledge_create_command` | Optional command override for creating new notes. | `""` |
| `editor` | The default CLI editor used by all system tools. | `"nvim"` |
| `preferred-scripting-language` | The preferred language for new CLI tools (NuShell, Python, Bash). | `"NuShell"` |

### Feature Toggles

| Flag | Behavior if `true` | Behavior if `false` |
| :--- | :--- | :--- |
| `enable-ai-workflow` | Loads agents, skills, inter-agent communication tools, AI status bar elements, and wraps AI CLI tools. | Disables all AI-specific logic, removes agent tracking from the status bar, and uses raw CLI binaries. |
| `enable-neovim` | Loads custom Neovim config with plugins and keybindings. | Uses the default system Neovim without custom setup. |
| `enable-tmux-on-ssh` | Automatically starts/attaches tmux on SSH login (non-Cider). | Standard shell login without automatic tmux. |
| `auto-switch-workspace-on-cd` | Automatically switches tmux session when `cd`-ing into a workspace. | Standard `cd` behavior; sessions stay unchanged. |
| `auto-switch-workspace-on-hgd` | `hgd` command triggers an automatic tmux session switch. | `hgd` changes directory but doesn't switch sessions. |
| `enable-auto-codesearch-with-cd` | Automatically prompts to search via CodeSearch when `cd` fails. | Suppresses the prompt on `cd` failure (but `cd --cs` still works). |

### AI Features (`ai_features` block)

| Flag | Behavior if `true` | Behavior if `false` |
| :--- | :--- | :--- |
| `enable_agent_knowledge` | Enables the agent knowledge section in `GEMINI.md`, instructing agents to use the knowledge directory. | Agents do not receive explicit instructions about the knowledge directory. |
| `enable_ai_ssa_creator_skill` | Links the `ai-ssa-creator` skill to `~/.gemini/skills/`. | The skill is unavailable to agents. |
| `enable_tmux_based_agent_comms` | Installs communication scripts (`iamdone`, `waiting`, `send-message-to-agent`), shows `@agent_name` in pane titles, and wraps CLI tools with `agent-wrapper`. | Inter-agent communication tools are not installed, pane titles are standard, and raw CLI binaries are used. |

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
