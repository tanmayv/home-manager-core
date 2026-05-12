# Prompt 12: Coder — Chunk 3 - Zsh Completion and Word Boundaries

**Persona:** Read `google3/experimental/users/goldental/agent_swarm/personas/coder/coder.md` — that defines your role. Read
`google3/experimental/users/goldental/agent_swarm/common/swarm_protocol.md` — shared rules for all agents.

**Input:** Read ALL of these before starting:

-   `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/implementation_plan.md` — full plan (focus on Chunk 3)
-   `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/project_brief.md`

**Response:** Write to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/12_coder_chunk3.md`

--------------------------------------------------------------------------------

## Mission

Implement **Chunk 3** from the implementation plan. This chunk covers Zsh autocompletion and sub-word directory-stop word deletion boundaries inside the Zsh line editor.

Specifically:
Modify [modules/zsh/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/zsh/default.nix) to:
1. Explicitly enable completions: add `enableCompletion = true;` inside `programs.zsh`.
2. Load Zsh's built-in `select-word-style` widget and set it to `bash` inside `programs.zsh.initContent`. This configures Zsh's `Ctrl+W` to stop at path slashes and punctuation instead of deleting entire paths at once.

--------------------------------------------------------------------------------

## Tasks

1.  Modify [modules/zsh/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/zsh/default.nix):
    *   Add `enableCompletion = true;` under `programs.zsh`:
        ```nix
          programs.zsh = {
            enable = true;
            enableCompletion = true;
            dotDir = "${config.xdg.configHome}/zsh";
        ```
    *   Load and configure `select-word-style` inside `initContent` right after `export COLORTERM=truecolor` (line 50):
        ```nix
            initContent = ''
              zmodload zsh/nearcolor
              export COLORTERM=truecolor

              # Enable Bash-style sub-word deletion boundaries (stops at slashes, etc.)
              autoload -Uz select-word-style
              select-word-style bash
        ```
2.  Verify syntax by running:
    ```bash
    nix-instantiate --parse /usr/local/google/home/tanmayvijay/home-manager-core/modules/zsh/default.nix
    ```

--------------------------------------------------------------------------------

## Deliverables

Write your response per the format defined in your persona (files modified, deviations from plan, parser status).

--------------------------------------------------------------------------------

## Constraints

-   Implement ONLY Chunk 3 — do not modify any other files.
-   Follow the Nix configuration specifications exactly.
