# Prompt 01: Scout — Shell Config and Auto-suggestions / Completion / Ctrl+W

**Persona:** Read `google3/experimental/users/goldental/agent_swarm/personas/scout/scout.md` — that defines your role. Read
`google3/experimental/users/goldental/agent_swarm/common/swarm_protocol.md` — shared rules for all agents.

**Input:** Read ALL of these before starting:

-   `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/project_brief.md`

**Response:** Write to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/01_scout.md`

**Doc:** Write to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/shell_config_research.md`

--------------------------------------------------------------------------------

## Mission

We want to configure Bash and Zsh within our Home Manager configuration to have:
1. Fully working tab completion.
2. `Ctrl+W` mapped to delete the last word.
3. Shell auto-suggestions enabled.

Your mission is to inspect our existing Zsh and Bash Home Manager modules, understand what is currently set up, and research the standard/recommended Home Manager options to implement these features cleanly. The Planner and Coder will rely on your research doc to write the exact Nix configurations.

--------------------------------------------------------------------------------

## Mandatory Research

1.  **Analyze Existing Configs**:
    *   Read [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix). Document how it is currently structured and what options are enabled.
    *   Read [modules/zsh/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/zsh/default.nix). Document how it is currently structured and what options are enabled.

2.  **Zsh Research**:
    *   Identify the Home Manager option to enable `zsh-autosuggestions` (e.g., `programs.zsh.enableAutosuggestions` or `programs.zsh.autosuggestions.enable` depending on the Home Manager release).
    *   Identify the Home Manager option to enable completion for Zsh (e.g., `programs.zsh.enableCompletion`).
    *   Research Zsh's word-deletion behavior. Is Ctrl+W mapped by default to `backward-kill-word`? If there are custom keybindings (e.g., vi-mode or custom keymaps), how can we ensure Ctrl+W is mapped correctly to delete a word without deleting the whole line or up to custom delimiters?

3.  **Bash Research**:
    *   Identify the Home Manager option to enable completion for Bash (e.g., `programs.bash.enableCompletion`).
    *   Research how to ensure Ctrl+W works for backward word deletion in Bash (usually `backward-kill-word` in readline/inputrc). Check if there's a way to manage this via Home Manager's readline configuration (`programs.readline`).
    *   Research auto-suggestions for Bash. Does Home Manager support a package/plugin for Bash auto-suggestions (like `ble.sh` or similar, or just simple bash history completion)? Check what packages are available and standard in Nix/Home Manager.

4.  **Verify dependencies**:
    *   Check if any additional plugins or packages need to be added to `home.packages` or as plugin options in `programs.zsh.plugins`.

--------------------------------------------------------------------------------

## Deliverables

Write your doc to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/shell_config_research.md` following the structure defined in your persona (Overview, Key Interfaces/Configs, Usage/Recommendations, Gotchas, Needs Verification).
Write a response summary to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/01_scout.md`.

--------------------------------------------------------------------------------

## Constraints

-   Stay within scope — do not change files or start implementing, only research and document.
-   Every claim must cite a file path or search result (e.g., Nix Home Manager options documentation).
-   Target 200+ lines for the research doc to ensure thoroughness.
