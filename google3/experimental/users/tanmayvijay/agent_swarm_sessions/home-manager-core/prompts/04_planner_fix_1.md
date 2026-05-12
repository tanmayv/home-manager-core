# Prompt 04 (Fix 1): Planner — Resolve Atuin Bash Conflict

**Persona:** Read `google3/experimental/users/goldental/agent_swarm/personas/planner/planner.md` — that defines your role.

**Input:** Read ALL of these:
- `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/implementation_plan.md` — your draft plan
- `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/05_reviewer_design.md` — the Reviewer's design audit feedback

**Response:** Write to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/04_planner_fix_1.md`

**Plan:** Update and overwrite `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/implementation_plan.md`

--------------------------------------------------------------------------------

## Mission

The Reviewer has returned a **NEEDS_FIX** verdict on your Implementation Plan because of a critical compatibility conflict between **Atuin** and **GNU Readline Up-Arrow Bindings** in Bash.

### The Issue
*   In [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix), Atuin is enabled with Bash integration (`programs.atuin.enableBashIntegration = true`).
*   By default, Atuin overrides the Up arrow (`\e[A`) key in Bash to launch the interactive Atuin history search UI.
*   If we implement Chunk 2 as planned (binding `\e[A` to `history-search-backward` in GNU Readline), Atuin's shell hooks will override it, rendering the native prefix history search completely inactive.

### The Solution
We must disable Atuin's Up-arrow override in Bash to allow the native GNU Readline prefix history search to function correctly on Up/Down keys, while still keeping Atuin active for `Ctrl+R` history search.
This is accomplished by adding `enable_up_arrow = false;` under `programs.atuin.settings` inside [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix).

### Your Task
1.  Update **Chunk 2** in `docs/implementation_plan.md` to include modifying `programs.atuin.settings` in `modules/bash/default.nix` to set `enable_up_arrow = false;`.
2.  Provide the updated `diff` Nix snippet in Chunk 2.
3.  Address the "discrepancy note" flagged by the Reviewer: explicitly mention in the plan's Approach section that we are pivoting from the Solutions Brief's Option A (Whitespace boundaries) to Option B (Sub-word boundaries) because it was explicitly chosen by the user.

--------------------------------------------------------------------------------

## Nix Diff Specification for Chunk 2

Ensure your updated Chunk 2 Nix configuration diff block looks like this:

```nix
  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      auto_sync = false;
      search_mode = "fuzzy";
+     enable_up_arrow = false;
    };
  };
```

--------------------------------------------------------------------------------

## Deliverables

1. Overwrite `docs/implementation_plan.md` with the fully updated plan.
2. Write a response summary to `responses/04_planner_fix_1.md` explaining what was updated.
