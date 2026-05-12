# Prompt 15: Reviewer — Tmux Scroll bindings Code Review

**Persona:** Read `google3/experimental/users/goldental/agent_swarm/personas/reviewer/reviewer.md` — that defines your role. Read
`google3/experimental/users/goldental/agent_swarm/common/swarm_protocol.md` — shared rules for all agents.

**Input:** Read ALL of these before starting:
- `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/project_brief.md`
- `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/14_coder_tmux_scroll.md` — the Coder's self-report

**Response:** Write to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/15_reviewer_tmux_scroll.md`

--------------------------------------------------------------------------------

## Mission

Review the code produced by the Coder against the Tmux scroll bindings task. Your job is to FIND BUGS or syntax errors, not confirm correctness. Check systematically.

Follow the review methodology defined in your persona, focusing on standard code verification.

--------------------------------------------------------------------------------

## Review Targets

-   **Task reviewed:** Alternate-screen mouse-wheel scrolling translation in Tmux.
-   **Files to inspect:** [modules/tmux/tmux-conf.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/tmux/tmux-conf.nix)
-   **Verification Actions**:
    1.  Open [modules/tmux/tmux-conf.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/tmux/tmux-conf.nix) and analyze the changes.
    2.  Verify the `bind -n WheelUpPane` and `bind -n WheelDownPane` are correctly inserted in `extraConfig`.
    3.  Verify that the double backslashes (e.g. `\"#{alternate_on}\"`) are correctly escaped inside the Nix string block.
    4.  Run the Nix parser dry-run to verify AST correctness:
        ```bash
        nix-instantiate --parse /usr/local/google/home/tanmayvijay/home-manager-core/modules/tmux/tmux-conf.nix
        ```
    5.  Ensure no extraneous changes or syntax defects were introduced.

--------------------------------------------------------------------------------

## Deliverables

Write your response per the format defined in your persona. Use verdict:
APPROVED, NEEDS_FIX, or NEEDS_NEW_PLAN.

Include a **Verification Log** listing all files you actually opened and checked.
