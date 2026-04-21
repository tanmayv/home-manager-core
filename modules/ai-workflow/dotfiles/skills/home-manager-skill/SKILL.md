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

- **Branching Strategy:** NEVER work directly on the `master` (or `main`) branch for your personal configuration.
- **Personal Branch:** Create a personal branch (e.g., `my-config`) off `stable` (or `master`) for your customizations.
- **Contributing Back:** Only use the `master` branch if you intend to submit a pull request or contribute changes back to the upstream repository.
- **Updates:** When updating, rebase your personal branch onto the latest upstream changes to preserve your customizations in `setup.nix`.

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

### 4. Updating the Configuration
1.  Run `check-for-update` to check for new stable versions.
2.  If prompted, confirm to update. The script will automatically rebase your branch and run `build-and-switch`.
3.  To update manually:
    - Fetch the latest stable tag: `git fetch origin tag stable --no-tags`
    - Rebase your current branch: `git rebase origin/stable`
    - Resolve any conflicts if they arise.
    - Apply changes: `build-and-switch`

### 5. Creating a New Release
1.  Ensure all changes are merged into the main branch (e.g., `master` or `main`).
2.  Create a new SemVer tag: `git tag vX.Y.Z` (replace with actual version).
3.  Update the floating `stable` tag to point to the new release:
    `git tag -f stable`
4.  Push the tags to the remote repository:
    `git push origin vX.Y.Z`
    `git push origin -f stable`

## Rules for Code Changes

- **Nix Scripting:** Use absolute paths to binaries from the Nix store (e.g., `${pkgs.fzf}/bin/fzf`).
- **Theming:** Use `modules/palette.nix` for colors to maintain the Tokyo Night aesthetic.
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
1. Create a new pane: `tmux split-window -h -P -F '#{pane_id}'`
2. Send command keys: `tmux send-keys -t %XX 'your-command' C-m`
3. Verify by capturing pane text: `tmux capture-pane -t %XX -p`
4. **CRITICAL**: Remember to kill the pane after each testing iteration to avoid clutter: `tmux kill-pane -t %XX`
