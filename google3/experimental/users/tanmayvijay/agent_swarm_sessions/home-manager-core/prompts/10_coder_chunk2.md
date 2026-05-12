# Prompt 10: Coder — Chunk 2 - Bash Completion, Readline, and Atuin Config

**Persona:** Read `google3/experimental/users/goldental/agent_swarm/personas/coder/coder.md` — that defines your role. Read
`google3/experimental/users/goldental/agent_swarm/common/swarm_protocol.md` — shared rules for all agents.

**Input:** Read ALL of these before starting:

-   `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/implementation_plan.md` — full plan (focus on Chunk 2)
-   `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/project_brief.md`

**Response:** Write to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/10_coder_chunk2.md`

--------------------------------------------------------------------------------

## Mission

Implement **Chunk 2** from the implementation plan. This chunk covers configuring Bash completions, GNU Readline (prefix suggestions and sub-word deletion), and resolving the Atuin Up-arrow key override conflict.

Specifically:
Modify [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix) to:
1. Explicitly enable completions: add `enableCompletion = true;` to `programs.bash`.
2. Declaratively configure GNU Readline: add the `programs.readline` submodule. Bind Up arrow (`\e[A`) to `history-search-backward`, Down arrow (`\e[B`) to `history-search-forward`, and `Ctrl+W` (`\C-w`) to `backward-kill-word`.
3. Configure Atuin settings: add `enable_up_arrow = false;` inside the existing `programs.atuin.settings` block.

--------------------------------------------------------------------------------

## Tasks

1.  Modify [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix):
    *   Add `enableCompletion = true;` under `programs.bash`:
        ```nix
          programs.bash = {
            enable = true;
            enableCompletion = true;
            shellAliases = {};
        ```
    *   Declare `programs.readline` submodule right after `programs.bash`:
        ```nix
          programs.readline = {
            enable = true;
            bindings = {
              "\\e[A" = "history-search-backward";
              "\\e[B" = "history-search-forward";
              "\\C-w" = "backward-kill-word";
            };
          };
        ```
    *   Update `programs.atuin.settings` block to disable Up-arrow capture:
        ```nix
          programs.atuin = {
            enable = true;
            enableBashIntegration = true;
            settings = {
              auto_sync = false;
              search_mode = "fuzzy";
              enable_up_arrow = false;
            };
          };
        ```
2.  Verify syntax by running:
    ```bash
    nix-instantiate --parse /usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix
    ```

--------------------------------------------------------------------------------

## Deliverables

Write your response per the format defined in your persona (files modified, deviations from plan, parser status).

--------------------------------------------------------------------------------

## Constraints

-   Implement ONLY Chunk 2 — do not modify Zsh files yet.
-   Follow the Nix configuration specifications exactly.
