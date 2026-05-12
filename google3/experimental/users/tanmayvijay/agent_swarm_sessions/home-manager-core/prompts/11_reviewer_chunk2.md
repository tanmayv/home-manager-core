# Prompt 11: Reviewer — Chunk 2 Code Review

**Persona:** Read `google3/experimental/users/goldental/agent_swarm/personas/reviewer/reviewer.md` — that defines your role. Read
`google3/experimental/users/goldental/agent_swarm/common/swarm_protocol.md` — shared rules for all agents.

**Input:** Read ALL of these before starting:
- `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/project_brief.md`
- `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/implementation_plan.md`
- `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/10_coder_chunk2.md` — the Coder's self-report

**Response:** Write to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/11_reviewer_chunk2.md`

--------------------------------------------------------------------------------

## Mission

Review the code produced by the Coder against Chunk 2 of the implementation plan. Your job is to FIND BUGS or syntax errors, not confirm correctness. Check systematically.

Follow the review methodology defined in your persona, focusing on standard code verification.

--------------------------------------------------------------------------------

## Review Targets

-   **Chunk reviewed:** Chunk 2 — Bash completion, GNU Readline bindings, and Atuin integration.
-   **Files to inspect:** [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix)
-   **Verification Actions**:
    1.  Open [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix) and analyze the changes.
    2.  Verify `enableCompletion = true;` is inside `programs.bash`.
    3.  Verify the `programs.readline` block is structurally valid, enabled, and has bindings:
        *   `"\\e[A" = "history-search-backward";`
        *   `"\\e[B" = "history-search-forward";`
        *   `"\\C-w" = "backward-kill-word";`
    4.  Verify `enable_up_arrow = false;` is added under `programs.atuin.settings`.
    5.  Run the Nix parser dry-run to verify AST correctness:
        ```bash
        nix-instantiate --parse /usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix
        ```
    6.  Ensure no extraneous, unneeded changes or syntax issues were introduced.

--------------------------------------------------------------------------------

## Deliverables

Write your response per the format defined in your persona. Use verdict:
APPROVED, NEEDS_FIX, or NEEDS_NEW_PLAN.

Include a **Verification Log** listing all files you actually opened and checked.
