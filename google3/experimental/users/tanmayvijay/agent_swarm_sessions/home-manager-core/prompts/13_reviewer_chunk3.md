# Prompt 13: Reviewer — Chunk 3 Code Review

**Persona:** Read `google3/experimental/users/goldental/agent_swarm/personas/reviewer/reviewer.md` — that defines your role. Read
`google3/experimental/users/goldental/agent_swarm/common/swarm_protocol.md` — shared rules for all agents.

**Input:** Read ALL of these before starting:
- `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/project_brief.md`
- `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/implementation_plan.md`
- `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/12_coder_chunk3.md` — the Coder's self-report

**Response:** Write to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/13_reviewer_chunk3.md`

--------------------------------------------------------------------------------

## Mission

Review the code produced by the Coder against Chunk 3 of the implementation plan. Your job is to FIND BUGS or syntax errors, not confirm correctness. Check systematically.

Follow the review methodology defined in your persona, focusing on standard code verification.

--------------------------------------------------------------------------------

## Review Targets

-   **Chunk reviewed:** Chunk 3 — Zsh Completion and Word Boundaries
-   **Files to inspect:** [modules/zsh/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/zsh/default.nix)
-   **Verification Actions**:
    1.  Open [modules/zsh/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/zsh/default.nix) and analyze the changes.
    2.  Verify `enableCompletion = true;` is added under `programs.zsh`.
    3.  Verify `autoload -Uz select-word-style` and `select-word-style bash` are loaded in `initContent`.
    4.  Run the Nix parser dry-run to verify AST correctness:
        ```bash
        nix-instantiate --parse /usr/local/google/home/tanmayvijay/home-manager-core/modules/zsh/default.nix
        ```
    5.  Ensure no extraneous changes or syntax defects were introduced.

--------------------------------------------------------------------------------

## Deliverables

Write your response per the format defined in your persona. Use verdict:
APPROVED, NEEDS_FIX, or NEEDS_NEW_PLAN.

Include a **Verification Log** listing all files you actually opened and checked.
