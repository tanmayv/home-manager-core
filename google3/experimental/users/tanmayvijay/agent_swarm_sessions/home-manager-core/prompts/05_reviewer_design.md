# Prompt 05: Reviewer — Design Plan Review

**Persona:** Read `google3/experimental/users/goldental/agent_swarm/personas/reviewer/reviewer.md` — that defines your role. Read
`google3/experimental/users/goldental/agent_swarm/common/swarm_protocol.md` — shared rules for all agents.

**Input:** Read ALL of these before starting:

-   `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/project_brief.md`
-   `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/solutions_brief.md`
-   `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/implementation_plan.md`

**Response:** Write to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/05_reviewer_design.md`

--------------------------------------------------------------------------------

## Mission

You are reviewing the PLAN, not code. The plan will be sent to Coders chunk by chunk. Your job is to catch bad assumptions and wrong directions before coding starts — catching these here is 10× cheaper than catching them after implementation.

Follow the review methodology defined in your persona, focusing on standard and deep adversarial checks.

## 1. Direction Check

-   **Solutions Brief conformance**: Does the plan follow the approved approach (Up/Down arrow prefix history search in Bash, directory/slash stopping boundaries in both shells, explicit completions)?
-   **Simplicity check**: Is this the simplest solution that meets the requirements?
-   **Scope alignment**: Compare the plan's deliverables against the project brief requirements point by point.

## 2. Assumption Audit

-   Are the assumptions about GNU Readline escape mapping (`\e[A`, `\e[B`, `\C-w`) correct?
-   What happens if terminal discipline or `stty werase` intercepts `Ctrl+W`? Is the mitigation (undefining `werase` inside `initExtra`) well-specified?
-   Does Zsh's `select-word-style bash` behave exactly as the user expects for sub-word boundary stopping?

## 3. Chunk & Boundary Review

-   **Chunk independence**: Can each chunk be built and tested separately?
-   **File Manifest spot-check**: Open [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix) and [modules/zsh/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/zsh/default.nix) and verify they exist, have the structure the plan says they have, and that the diff target lines are accurate.
-   **Syntax and validation check**: Is the dry-run validation command `nix-instantiate --parse` correct and sufficient to catch syntax errors in Nix? Does `build-and-switch` correctly evaluate the options?

--------------------------------------------------------------------------------

## Review Targets

-   **Key risk areas**: Escape sequences, readline binding structures in Home Manager, Zsh line editor (ZLE) syntax.
-   **Ecosystem compatibility**: Confirm these configurations do not break Atuin and Zoxide integrations in the files.

--------------------------------------------------------------------------------

## Deliverables

Write your response per the format defined in your persona (Verdict, Approach Assessment, Critical Findings, Reality Check, Verification Log, What's Missing, Observations). Use verdict:
APPROVED, NEEDS_FIX, or NEEDS_NEW_PLAN.
