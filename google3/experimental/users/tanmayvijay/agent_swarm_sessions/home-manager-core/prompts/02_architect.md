# Prompt 02: Architect — Shell Enhancements Solutions Brief

**Persona:** Read `google3/experimental/users/goldental/agent_swarm/personas/architect/architect.md` — that defines your role. Read
`google3/experimental/users/goldental/agent_swarm/common/swarm_protocol.md` — shared rules for all agents.

**Input:** Read ALL of these before starting:

-   `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/project_brief.md`
-   `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/shell_config_research.md`

**Response:** Write to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/02_architect.md`

**Solutions Brief:** Write to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/solutions_brief.md`

--------------------------------------------------------------------------------

## Mission

Evaluate the strategic direction for this project BEFORE any implementation planning begins. Generate alternative approaches, compare their tradeoffs, and recommend the best path forward.

The Conductor will present your Solutions Brief to the user for approval. Only after the user approves a direction will the Planner begin detailed implementation planning. A wrong direction here is far more expensive than a wrong function signature later.

### Context & Specific Decisions Required

The user wants to enable Tab Completion, `Ctrl+W` word deletion, and Auto-suggestions in both Bash and Zsh. We need you to evaluate and present distinct options for the following architectural questions:

1.  **Bash Auto-suggestions Strategy**:
    *   *Option A (Minimalist)*: Map GNU Readline Up/Down Arrows to prefix-based history searches. This is native, zero-dependency, extremely lightweight, and uses standard readline bindings.
    *   *Option B (Maximalist)*: Enable `ble.sh` (Bash Line Editor) integration in Home Manager (`programs.bash.blesh.enable = true;`). This provides true fish-like inline suggestions, but replaces GNU Readline completely, introducing minor complexity and possible keymap overrides.

2.  **Consistent Word Deletion (`Ctrl+W`) Boundaries**:
    *   *Option A (Whitespace boundaries)*: Keep `Ctrl+W` treating only spaces as boundaries (Readline's default `unix-word-rubout` and standard Zsh default). Delimiter characters like `/` do not stop the deletion (e.g., deleting `/usr/local/bin` deletes the entire path).
    *   *Option B (Punctuation/Sub-word boundaries)*: Configure both shells to stop at slashes and punctuation (Readline `backward-kill-word` and Zsh `select-word-style bash` or adjusted `WORDCHARS`). Pressing `Ctrl+W` on `/usr/local/bin` deletes only `bin`, then `local`, etc.

3.  **Syntax Defect Remediation**:
    *   Identify how we should orchestrate the fix for the pre-existing syntax error in [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix) as a pre-requisite task.

--------------------------------------------------------------------------------

## Deliverables

1.  **Solutions Brief** — written to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/solutions_brief.md`, following the structure defined in your persona (Problem Restatement, Approach Options, Recommended Approach, Key Risks & Mitigations, Pivot Triggers, Open Questions for User).
2.  **Response summary** — recommended approach, rationale, open questions, and any suggestions for the Conductor.

--------------------------------------------------------------------------------

## Constraints

-   Do NOT produce implementation plans, function signatures, or chunk decompositions — that is the Planner's job.
-   Every approach must be grounded in scout findings — no speculation.
-   Include at least one "simpler than you think" option.
-   Keep the Solutions Brief readable in 5 minutes.
