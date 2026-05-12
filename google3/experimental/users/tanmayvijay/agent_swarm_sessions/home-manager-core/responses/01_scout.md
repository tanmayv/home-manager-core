# Scout Response — Prompt 01 (Shell Config Research)

---

## 1. Topics Covered & Key Findings

I have conducted exhaustive research on configuring **Tab Completion**, **Word Deletion (`Ctrl+W`)**, and **Auto-suggestions** for both Bash and Zsh using standard Home Manager declarative options.

*   **Tab Completion**:
    *   **Zsh**: Natively enabled by default, but can be explicitly set via `programs.zsh.enableCompletion = true;`.
    *   **Bash**: Omitted in current configs; should be explicitly enabled via `programs.bash.enableCompletion = true;`.
*   **Word Deletion (`Ctrl+W`)**:
    *   **Bash/Readline**: Configured via `programs.readline.bindings`. Can be set to space-delimited (`unix-word-rubout`) or sub-word/punctuation-delimited (`backward-kill-word`).
    *   **Zsh/ZLE**: Configured via Zsh options in `initContent`. Can be kept at standard space-delimited, or configured to stop at path slashes using `select-word-style bash` or `WORDCHARS` modifications.
*   **Auto-suggestions**:
    *   **Zsh**: Structured option `programs.zsh.autosuggestion.enable = true;` is already successfully configured.
    *   **Bash**: Recommended lightweight prefix-based history search via `programs.readline.bindings` or high-performance inline ghost suggestions via `programs.bash.blesh.enable = true;`.

---

## 2. Gaps, Concerns, and Needs Verification

1.  **Bash Syntax Defect**:
    *   ⚠️ `modules/bash/default.nix` currently contains a syntax defect on lines 53-54 (duplicate closing quotes `'';`). This must be resolved before any Nix evaluation can succeed.
2.  **stty Interception**:
    *   `stty werase` may intercept `Ctrl+W` at the terminal level. We recommend testing `stty werase undef` in `programs.bash.initExtra` to guarantee the Readline keybindings function correctly.
3.  **`ble.sh` Integration Check**:
    *   If the Conductor opts for fish-like auto-suggestions in Bash via `ble.sh` (`programs.bash.blesh.enable = true;`), we need to verify if it overrides custom `programs.readline` bindings.

---

## 3. Suggestions for the Conductor

*   **Next Invocation (Planner)**:
    *   Direct the Planner to create two options/strategies:
        1.  *Minimalist Strategy*: Native readline prefix-search for Bash history and standard `Ctrl+W` keybindings.
        2.  *Maximalist Strategy*: Full `ble.sh` integration for fish-like inline ghost suggestions in Bash, matched with customized `ble-bind` keymaps to preserve word deletion.
    *   The Planner can formulate exact implementation tasks for the Coder based on our research doc: [shell_config_research.md](file:///usr/local/google/home/tanmayvijay/home-manager-core/google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/docs/shell_config_research.md).
