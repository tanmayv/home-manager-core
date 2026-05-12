# Prompt 04: Planner — Shell Enhancements Implementation Plan

**Persona:** Read `google3/experimental/users/goldental/agent_swarm/personas/planner/planner.md` — that defines your role.
Read `google3/experimental/users/goldental/agent_swarm/common/swarm_protocol.md` — shared rules for all agents.

**Input:** Read ALL of these before starting:

-   `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/project_brief.md`
-   `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/solutions_brief.md` — the approved strategic direction
-   `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/shell_config_research.md` — the background research

**Response:** Write to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/04_planner.md`

**Plan:** Write to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/implementation_plan.md`

--------------------------------------------------------------------------------

## Mission

Design a detailed implementation plan for this project based on the approved approach in the Solutions Brief.

### Approved Strategic Decisions

The user has explicitly approved the recommended approach:
1.  **Bash Auto-suggestions**: **Option A (Prefix History Search)**. Bind GNU Readline Up/Down Arrows to history prefix searches (`history-search-backward` / `history-search-forward`).
2.  **Word Deletion Boundaries**: **Option B (Sub-word stopping/Stop at Slashes)**.
    *   *Bash*: Configure `Ctrl+W` to trigger `backward-kill-word` in GNU Readline.
    *   *Zsh*: Load `select-word-style bash` or remove `/` from `WORDCHARS` in Zsh `initContent`.
3.  **Tab Completion**: Explicitly enable standard shell completions in both shells using Home Manager attributes (`programs.bash.enableCompletion = true;` and `programs.zsh.enableCompletion = true;`).
4.  **Syntax Error Prerequisite Fix**:
    *   Fix the duplicate closing quotes `'';` at [modules/bash/default.nix:54](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix#L54) as a pre-requisite task before applying any other config changes.

--------------------------------------------------------------------------------

## Deliverables

Write your plan with the following required sections, in order:

1.  **Problem Statement** — Plain English description of the problem, user impact, and current state limitations.
2.  **Approach Justification** — Why prefix history search + sub-word boundaries fit perfectly, and how they mitigate risks (such as avoiding clashes with Atuin).
3.  **Technical Overview** — Analysis of existing shell configuration structures and major Nix option mappings.
4.  **File Manifest** — Table of all files to modify (specifically [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix) and [modules/zsh/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/zsh/default.nix)).
5.  **Phase 0: Assumption Validation / Test Spike** — Specific validation script or manual verification steps to check for `stty werase` interception or custom keymap overlaps.
6.  **Implementation Chunks** — Numbered, ordered, self-contained chunks:
    *   **Chunk 1**: Syntax defect fix in `modules/bash/default.nix`.
    *   **Chunk 2**: Configure Bash tab completion, prefix-based history suggestions, and sub-word word-deletion boundaries via GNU Readline.
    *   **Chunk 3**: Configure Zsh tab completion and sub-word word-deletion boundaries.
    *   *For each chunk*: list files to modify, lines/sections, exact Nix configurations to be written, and specific manual validation steps.
7.  **Spec Self-Check** — The 3-point validation criteria check.

--------------------------------------------------------------------------------

## Constraints

-   Do NOT re-evaluate the strategic direction — implement the approved Options.
-   Do NOT write code — produce a plan only.
-   Write clean, compile-safe Nix syntax snippets within the plan so the Coder has a direct blueprint.
