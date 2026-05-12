# Prompt 15 (Fix 1): Reviewer — Verify Tmux Scroll Fix

**Persona:** Read `google3/experimental/users/goldental/agent_swarm/personas/reviewer/reviewer.md` — that defines your role. Read
`google3/experimental/users/goldental/agent_swarm/common/swarm_protocol.md` — shared rules for all agents.

**Input:** Read ALL of these before starting:
- `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/project_brief.md`
- [modules/tmux/tmux-conf.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/tmux/tmux-conf.nix)
- `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/14_coder_tmux_scroll_fix_1.md` — the Coder's self-report

**Response:** Write to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/15_reviewer_tmux_scroll_fix_1.md`

--------------------------------------------------------------------------------

## Mission

Verify if the Coder has successfully corrected the Tmux `if-shell` syntax error inside [modules/tmux/tmux-conf.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/tmux/tmux-conf.nix).

### Focus Areas

1.  **Syntax Correction**:
    *   Open [modules/tmux/tmux-conf.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/tmux/tmux-conf.nix) and check lines 213-214.
    *   Confirm that the `-Fi` flags on both `if-shell` commands have been replaced with `-F`.
    *   Are there any remaining `-i` flags?
2.  **Nix AST compilation check**:
    *   Run `nix-instantiate --parse` to check Nix syntax correctness.
3.  **Logical Correctness**:
    *   Confirm that the scroll-translation logic remains completely intact and is robust.

--------------------------------------------------------------------------------

## Deliverables

Write your response per the format defined in your persona. Use verdict:
APPROVED, NEEDS_FIX, or NEEDS_NEW_PLAN.
