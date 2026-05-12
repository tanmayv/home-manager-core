# Prompt 09: Reviewer — Chunk 1 Code Review

**Persona:** Read `google3/experimental/users/goldental/agent_swarm/personas/reviewer/reviewer.md` — that defines your role. Read
`google3/experimental/users/goldental/agent_swarm/common/swarm_protocol.md` — shared rules for all agents.

**Input:** Read ALL of these before starting:
- `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/project_brief.md`
- `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/implementation_plan.md`
- `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/08_coder_chunk1.md` — the Coder's self-report

**Response:** Write to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/09_reviewer_chunk1.md`

--------------------------------------------------------------------------------

## Mission

Review the code produced by the Coder against Chunk 1 of the implementation plan. Your job is to FIND BUGS or syntax errors, not confirm correctness. Assume the code has issues and check systematically.

Follow the review methodology defined in your persona, focusing on standard code verification.

--------------------------------------------------------------------------------

## Review Targets

-   **Chunk reviewed:** Chunk 1 — Bash Config Syntax Fix
-   **Files to inspect:** [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix)
-   **Verification Actions**:
    1.  Open [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix) and check lines 53-55.
    2.  Verify that only a single closing `'';` terminates the `initExtra` block on line 53, followed immediately by the closing curly brace `};` on line 54.
    3.  Run the Nix parser dry-run to verify AST correctness:
        ```bash
        nix-instantiate --parse /usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix
        ```
    4.  Confirm no extra lines, functions, or comments were introduced.

--------------------------------------------------------------------------------

## Deliverables

Write your response per the format defined in your persona (Verdict, Approach Assessment, Critical Findings, Reality Check, Verification Log, What's Missing, Observations). Use verdict:
APPROVED, NEEDS_FIX, or NEEDS_NEW_PLAN.

Include a **Verification Log** listing all files you actually opened and checked.
