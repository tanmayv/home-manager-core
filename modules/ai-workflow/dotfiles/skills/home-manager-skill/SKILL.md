---
name: home-manager-skill
description: Expert guidance for managing and updating the Home Manager configuration in this repository.
---

# Home Manager Skill

This skill provides procedures and standards for modifying the Minimal Cloudtop Home Manager configuration.

## Core Principles

- **Modularity:** Always create or modify isolated modules in the `modules/` directory.
- **User-Agnosticism:** Nix modules MUST NOT hardcode usernames or paths. Ingest `username` and `userSettings` as arguments.
- **Centralized Settings:** All user-facing toggles must go into `setup.nix`.
- **Documentation:** When adding a new flag to `setup.nix`, update `docs/Customization.md`.
- **Validation:** Always use `build-and-switch` to apply and verify changes.

## Git Best Practices

- **Branching Strategy:** 
  * **Strategy 2 (Recommended):** Manage your personal configuration in a separate repository (e.g., `~/.config/home-manager`) importing `minimal-cloudtop` core and `extensions` as Flake inputs. You can commit directly to its `main` branch.
  * **Strategy 1 (Legacy):** If you are customizing a direct clone of the core repository, NEVER work directly on the `main` branch. Create a personal branch (e.g., `my-config`) off `stable`.
- **Contributing Back:** Only use the core `main` branch if you intend to submit a pull request or contribute changes back to the upstream repository.
- **Updates:** 
  * **Strategy 2:** Update Flake inputs using `nix flake update` in your personal configuration directory.
  * **Strategy 1:** Rebase your personal branch onto the latest upstream changes to preserve your customizations in `setup.nix`.

## Process and Planning Guidelines

When requested to make changes by the user:

1. **Use Non-Main Branch**: Always perform work on a non-`main` branch (e.g., `develop` or a specific feature branch).
2. **Implementation Plan**:
   - Create an implementation plan before making changes (when in planning mode).
   - **Include Git steps** in the plan: specify the branch to use and the commit step at the end.
3. **Commit After Approval**: Once the implementation plan is approved and changes are made and verified, perform a `git commit` to save the work on the branch.

## Common Workflows

### 1. Adding a New Feature/Module
1.  Create a new directory in `modules/` (e.g., `modules/my-feature/`).
2.  Create a `default.nix` in that directory.
3.  Add an `enable-my-feature` toggle to `setup.nix`.
4.  Update `home.nix` to conditionally import the new module based on the toggle.
5.  Document the new toggle in `docs/Customization.md`.
6.  Run `build-and-switch`.

### 2. Updating the Tmux Palette
1.  Open `modules/tmux-palette.nix`.
2.  Add the new command or workflow to the palette configuration.
3.  Ensure the command is discoverable and follows existing patterns.
4.  Run `build-and-switch`.

### 3. Adding a New AI Skill
1.  Create a directory in `modules/ai-workflow/dotfiles/skills/{skill_name}/`.
2.  Create a `SKILL.md` with YAML frontmatter (name and description).
3.  (Optional) Add a toggle in `setup.nix` and `modules/ai-workflow/default.nix` if it should be optional.
4.  Run `build-and-switch`.

### 4. Adding Custom Hooks for Gemini and Jetski
1.  Create hook scripts in `modules/ai-workflow/dotfiles/hooks/placeholders/` (or a specific directory for the feature).
2.  Ensure scripts read JSON from stdin and output valid JSON to stdout (strictly JSON for Gemini!).
3.  Update `modules/ai-workflow/dotfiles/hooks/hooks.json` for Gemini hooks.
4.  Update `modules/ai-workflow/dotfiles/hooks/jetski_hooks.json` for Jetski hooks.
5.  Run `build-and-switch` to apply changes and link files.

### 5. Updating the Configuration

#### Strategy 2 (Recommended - Flake Input)
1. Navigate to your personal configuration directory:
   ```bash
   cd ~/.config/home-manager
   ```
2. Update the Flake inputs (this fetches the latest commits for the rolling `stable` tags):
   ```bash
   nix flake update
   ```
3. Apply the updates:
   ```bash
   build-and-switch
   ```

#### Strategy 1 (Legacy - Direct Clone & Rebase)
1. Run `check-for-update` to check for new stable versions.
2. If prompted, confirm to update. The script will automatically rebase your branch and run `build-and-switch`.
3. To update manually:
   - Fetch the latest stable tag: `git fetch origin tag stable --no-tags`
   - Rebase your current branch: `git rebase origin/stable`
   - Apply changes: `build-and-switch`

### 6. Creating a New Release
1. Ensure all changes are merged into the main branch (e.g., `main`).
2. Create a new SemVer tag: 
   ```bash
   git tag -a vX.Y.Z -m "Release version X.Y.Z"
   ```
3. Update the floating `stable` tag to point to the new release:
   ```bash
   git tag -d stable
   git tag -a stable -m "Stable release vX.Y.Z"
   ```
4. Push the tags to the remote repository:
   ```bash
   git push origin vX.Y.Z
   git push origin stable --force
   ```

## Rules for Code Changes

- **Nix Scripting:** Use absolute paths to binaries from the Nix store (e.g., `${pkgs.fzf}/bin/fzf`).
- **Theming:** Use `modules/palette.nix` for colors to maintain the Tokyo Night aesthetic.
- **Tmux Popups (`display-popup`):** When creating bindings that launch a popup (`display-popup -E`), tmux format variables like `#S` may not expand automatically. Instead, wrap the command in a shell and fetch the variable dynamically (e.g., `display-popup -E "bash -c 'S=\$(tmux display-message -p \"#S\"); command \"\$S\"'"`).
- **No Hacks:** Avoid suppressing warnings or using non-idiomatic Nix patterns.

## Guide on Developing CLI Tools

### Language Preference
- Check the `preferred-scripting-language` option in `setup.nix`.
- Follow the defined language for new scripts (NuShell, Python, or Bash). NuShell is the default.

### Modularity and Options
- Whenever possible, encapsulate new CLI tools or significant features in their own **Nix module** (e.g., in `modules/{feature_name}/default.nix`).
- Provide module options (using `mkOption`) to customize the behavior of the tool.
- **CRITICAL**: Always provide an `enable` option to allow the user to disable the tool/feature completely.

### Implementation Plans
- Whenever possible, include **examples** of usage or configuration in the implementation plan to make it clearer for the user.

### Testing Iterations in Tmux
When testing interactive tools or scripts:
1. Create a new pane in the window the agent is running (to avoid affecting the user's workflow in other windows): `tmux split-window -h -P -F '#{pane_id}' -t "$TMUX_PANE"`
2. Send command keys: `tmux send-keys -t %XX 'your-command' C-m`
3. Verify by capturing pane text: `tmux capture-pane -t %XX -p`
4. **CRITICAL**: Remember to kill the pane after each testing iteration to avoid clutter: `tmux kill-pane -t %XX`
