# Gemini AI Workflow & Coding Conventions

This `GEMINI.md` provides context and instructions for AI agents working within this repository. This repository contains a Nix Home Manager configuration designed to create a beginner-friendly, AI-focused terminal environment (Minimal Cloudtop).

## Project Goals
- Create a powerful but accessible terminal experience using Tmux, Zsh, and modern CLI tools (Zoxide, Atuin, Fzf).
- Focus on mouse-driven usability (e.g., clickable status bars for session switching).
- Integrate AI workflows seamlessly into the terminal experience.

## Architectural Patterns
- **Modular Structure**: Keep configurations isolated within the `modules/` directory. Each logical component (e.g., `tmux`, `zsh`, `scripts`) should have its own subdirectory or Nix file.
- **User-Agnostic Modules**: Modules MUST NOT hardcode usernames, home paths, or configuration locations. They must ingest `username` or `userSettings` (from `setup.nix`) as arguments to maintain portability.
- **Centralized Settings**: `setup.nix` is the absolute Source of Truth for user-specific variables.

## Nix Scripting Conventions
- **Evaluation-Time Injection**: Always inject Nix variables (e.g., `${userSettings.editor}`, `${userSettings.config-location}`) directly into shell scripts at Nix evaluation time via string interpolation. Avoid using `nix eval` at runtime.
- **Explicit Binary Paths**: When creating scripts via `writeScriptBin`, use absolute paths to binaries from the Nix store (e.g., `${pkgs.fzf}/bin/fzf` instead of `fzf`) to ensure pure and reliable execution regardless of the user's `$PATH`.
- **Python for Complex Logic**: Use `pkgs.writeScriptBin` with a Python 3 shebang (`#!${pkgs.python3}/bin/python3`) for scripts requiring complex data handling, such as the `tmux-palette` LRU ranking or status bar formatting.
- **CLI Configuration**: When writing configuration for a new CLI tool, ALWAYS try to read its `man` page or internal documentation to understand the correct syntax and available options before implementing.

## Terminal & Shell Conventions
- **Unified Theming**: Always import and use `modules/palette.nix` for colors to ensure a consistent aesthetic (Tokyo Night) across all tools (Tmux, Zsh, etc.).
- **Google3 Awareness**: Scripts and prompts should be "CitC-aware" where appropriate. For example, the Zsh prompt (`customize_pure_prompt`) and Tmux sessionizer specifically format `/google/src/cloud/$USER` paths.

## Tmux Configuration Specifics
- **Mouse-Centric UX**: Maintain and respect the custom `MouseDown1Status` bindings. The UI relies on custom `#[range=...]` tags to allow users to switch sessions or trigger the command palette via mouse clicks.
- **Status Bar Hierarchy**: Use a dynamic status bar that expands up to 3 lines based on context. `status-format[0]` is the primary bar for window navigation. `status-format[1]` shows Active Sessions (if multiple) or Active Agents. `status-format[2]` shows Active Agents (if multiple sessions AND agents exist).
- **Vim Interoperability**: Navigation shortcuts (`C-h/j/k/l`) MUST remain "smart." The `is_vim` regex check must be maintained and updated to allow seamless pane switching that respects Vim, Neovim, Helix, and Lazygit.
- **Command Palette**: Add new commands to the `tmux-palette` configuration within `modules/tmux-palette.nix`. When adding support for a new CLI tool, ALWAYS prefer adding its most common commands or workflows to the tmux palette to improve discoverability and ease of use.

## Versioning & User Customization
- **Release Strategy**: The project uses SemVer tags (e.g., `v0.1.0`) and a floating `stable` tag for releases.
- **User Customizations**: Users are instructed to create a personal branch (e.g., `my-config`) off `stable` to modify `setup.nix`. 
- **Updates**: When updating the configuration via `check-for-update` or manually, the agent/script must **rebase** the user's branch onto the new `stable` tag (`git rebase origin/stable`) to preserve their customizations in `setup.nix` without merge conflicts.

## AI Workflow Integration
- **AI Workflow Layout**: AI skills, hooks, and agents are linked from `modules/ai-workflow/dotfiles/` to the standard `~/.gemini/` location.
- **Localized Instructions**: Use localized `GEMINI.md` files within specific skill or agent directories to provide sub-agent context.
- **Building Changes**: Always advise or use the `build-and-switch` command to apply Nix configuration changes to the system.

## Agent Knowledge & Note Management
- **Knowledge Directory**: Persistent agent knowledge (markdown notes) is stored in the directory specified by `local_agent_knowledge_dir` in `setup.nix` (default: `~/agent_knowledge`).
- **Creating Notes**: Use the command specified by `local_agent_knowledge_create_command` (e.g., `nn`) to create new persistent notes.
- **Protocol**: When asked to remember something or take a note, agents should check this directory for relevant existing notes or create a new one using a descriptive filename.
