# Prompt 08: Coder — Chunk 1 - Bash Config Syntax Fix

**Persona:** Read `google3/experimental/users/goldental/agent_swarm/personas/coder/coder.md` — that defines your role. Read
`google3/experimental/users/goldental/agent_swarm/common/swarm_protocol.md` — shared rules for all agents.

**Input:** Read ALL of these before starting:

-   `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/implementation_plan.md` — full plan (focus on Chunk 1)
-   `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/project_brief.md`

**Response:** Write to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/08_coder_chunk1.md`

--------------------------------------------------------------------------------

## Mission

Implement **Chunk 1** from the implementation plan. This chunk covers fixing a pre-existing syntax error in the Bash Home Manager module.

Specifically:
Modify [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix) to remove the duplicate string/attribute terminators (`'';`) at line 54. This is a hard blocker for Nix evaluations and must be resolved before any subsequent configurations are introduced.

--------------------------------------------------------------------------------

## Tasks

1.  Modify [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix):
    *   Verify lines 53-54:
        ```nix
            '';
            '';
        ```
    *   Remove the duplicate `'';` on line 54, leaving a single `'';` to terminate the `initExtra` string block.
2.  Run the Nix syntax parsing parser:
    ```bash
    nix-instantiate --parse /usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix
    ```
3.  **Pass criteria**: The parser command prints the AST successfully or exits 0 without syntax errors.

--------------------------------------------------------------------------------

## Deliverables

Write your response per the format defined in your persona (files modified, deviations from plan, parser/build status).

--------------------------------------------------------------------------------

## Constraints

-   Implement ONLY Chunk 1 — do not add keybindings, completions, or Zsh changes yet.
-   Follow the plan exactly.
-   Do not add inline comments to [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix) when making this fix.
