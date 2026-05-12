# Shell Configuration Research: Tab Completion, Word Deletion, and Auto-suggestions in Home Manager

---

## 1. Overview

This document outlines the research, findings, and recommendations for enhancing the Bash and Zsh shell environments within the Minimal Cloudtop Home Manager configuration. 

Our goals are:
1.  **Fully Working Tab Completion**: Ensure autocomplete works out of the box for both Bash and Zsh.
2.  **Robust Word Deletion (`Ctrl+W`)**: Ensure pressing `Ctrl+W` deletes the last word in a clean, standard, and configurable manner.
3.  **Shell Auto-suggestions**: Provide real-time, fish-like shell suggestions as the user types in both Bash and Zsh.

This research aims to provide the Architect, Planner, and Coder agents with the precise Home Manager options, packages, configurations, and known edge cases to implement these features cleanly and modularly.

---

## 2. Existing Configuration Analysis

### 2.1 Bash Configuration
*   **File**: [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix)
*   **Current Structure**:
    *   `programs.bash` is enabled (`enable = true;`).
    *   No completion options are configured (`programs.bash.enableCompletion` is omitted, defaulting to `true` but not explicitly declared).
    *   `initExtra` contains basic configuration: color support, history size/file configurations (`HISTCONTROL=ignoredups:erasedups`, `shopt -s histappend`, `HISTSIZE=10000`, `HISTFILESIZE=20000`), an SSH agent socket auto-fix script, a CLI update checker, and autostarting `tmux-sessionizer` when logging in over SSH.
    *   Integrates `programs.zoxide` (directory jumper) and `programs.atuin` (shell history SQLite tracker) with Bash integrations enabled.
*   **Syntax/Formatting Gotcha**:
    *   ⚠️ Lines 53-54 contain duplicate closing quotes/semicolons:
        ```nix
        53:     '';
        54:     '';
        ```
        This is a syntax defect in the existing codebase that should be flagged for cleanup by the Coder.

### 2.2 Zsh Configuration
*   **File**: [modules/zsh/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/zsh/default.nix)
*   **Current Structure**:
    *   `programs.zsh` is enabled (`enable = true;`).
    *   `programs.zsh.autosuggestion.enable = true;` is explicitly set, satisfying Zsh's auto-suggestion requirement natively.
    *   `programs.zsh.syntaxHighlighting.enable = true;` is set.
    *   `initContent` handles nearcolor support, custom keymaps for autosuggestion (`bindkey '^E' autosuggest-accept`) and history navigation (`bindkey '^P' up-line-or-history`, `bindkey '^N' down-line-or-history`), history duplication options, Pure prompt initialization, SSH-agent socket auto-fix, CLI update checker, and SSH autostart of `tmux-sessionizer`.
    *   Integrates `programs.zoxide` and `programs.atuin` with Zsh integrations enabled.

---

## 3. Key Interfaces and Home Manager Options

### 3.1 Zsh Interfaces
*   **Option**: `programs.zsh.enableCompletion` (type: `bool`, default: `true`)
    *   *Role*: Runs `compinit` and configures Zsh completion system.
*   **Option**: `programs.zsh.autosuggestion.enable` (type: `bool`, default: `false`)
    *   *Role*: Enables `zsh-autosuggestions` seamlessly, injecting the plugin.
    *   *Note*: The option `programs.zsh.enableAutosuggestions` is deprecated in modern Home Manager releases; `programs.zsh.autosuggestion.enable` is the correct structured alternative.
*   **Zsh Line Editor (ZLE) Widgets**:
    *   `backward-kill-word`: Deletes word backward based on `$WORDCHARS`.
    *   `select-word-style`: Advanced Zsh module to dynamically set word boundaries (e.g., `bash`, `normal`, `shell`, `whitespace`).

### 3.2 Bash & Readline Interfaces
*   **Option**: `programs.bash.enableCompletion` (type: `bool`, default: `true`)
    *   *Role*: Sources necessary completion scripts in `.bashrc`.
*   **Option**: `programs.bash.blesh.enable` (type: `bool`, default: `false`)
    *   *Role*: Enables **ble.sh** (Bash Line Editor), providing high-performance syntax highlighting, auto-suggestions, and vim-mode in pure Bash.
*   **Option**: `programs.readline` (submodule)
    *   *Role*: Declaratively configures `~/.inputrc` for GNU Readline.
    *   *Option*: `programs.readline.enable` (type: `bool`, default: `false`)
    *   *Option*: `programs.readline.bindings` (type: `attribute set`)
        *   Map specific keystrokes to Readline functions (e.g., `"\C-w" = "unix-word-rubout";`).
    *   *Option*: `programs.readline.variables` (type: `attribute set`)
        *   Set Readline variables (e.g., `editing-mode = "emacs";`).

---

## 4. In-Depth Feature Research & Implementation Recommendations

### 4.1 Shell Completion (Tab Completion)
*   **Zsh**:
    *   Zsh completion is extremely robust. Since `programs.zsh.enableCompletion` defaults to `true`, it is already implicitly enabled. To follow best practices of explicit configuration, we should declare:
        ```nix
        programs.zsh.enableCompletion = true;
        ```
*   **Bash**:
    *   Explicitly enable completion in Bash by adding:
        ```nix
        programs.bash.enableCompletion = true;
        ```
    *   *Gotcha*: On non-NixOS Linux (generic Linux, e.g., Cloudtop), Home Manager's completion scripts depend on system-wide exposure or proper linking. In `home.nix`, `targets.genericLinux.enable = true;` is already set, which handles linking standard profile paths to allow user-installed completions to work properly.

### 4.2 Word Deletion (`Ctrl+W`)
The default word-deletion behavior in terminal shells can be confusing because "words" are defined differently by GNU Readline (used by Bash) and ZLE (used by Zsh).

#### 4.2.1 GNU Readline / Bash Behavior
*   By default, `Ctrl+W` in Readline is bound to `unix-word-rubout`, which treats only **whitespace** as a boundary. E.g., pressing `Ctrl+W` on `/usr/local/bin` deletes the entire string.
*   Conversely, `Alt-Backspace` is bound to `backward-kill-word`, which treats **punctuation and non-alphanumeric characters** as boundaries. E.g., pressing `Alt-Backspace` on `/usr/local/bin` deletes only `bin`, then `local`, then `usr`.
*   **Recommendation**: To ensure `Ctrl+W` deletes the last word consistently, we have two choices depending on user preference:
    1.  *Option A (Standard Bash)*: Keep or explicitly map `Ctrl+W` to `unix-word-rubout` (whitespace-delimited):
        ```nix
        programs.readline = {
          enable = true;
          bindings = {
            "\\C-w" = "unix-word-rubout";
          };
        };
        ```
    2.  *Option B (Sub-word stopping)*: Map `Ctrl+W` to `backward-kill-word` so it stops at path slashes and punctuation:
        ```nix
        programs.readline = {
          enable = true;
          bindings = {
            "\\C-w" = "backward-kill-word";
          };
        };
        ```

#### 4.2.2 Zsh / ZLE Behavior
*   By default, `Ctrl+W` in Zsh runs `backward-kill-word`. Zsh determines word boundaries using the `WORDCHARS` environment variable.
*   The default Zsh `WORDCHARS` contains many punctuation marks: `*?_-.[]~=/&;!#$%^(){}<>`. Since `/` is in `WORDCHARS`, Zsh treats `/usr/local/bin` as a single word and deletes the entire path.
*   **Recommendation**: To achieve consistency between the two shells:
    1.  *Option A (Standard Zsh/Whitespace-delimited)*: Keep Zsh's default behavior.
    2.  *Option B (Sub-word stopping / Stop at Slashes)*: We can configure Zsh to use the Bash-like sub-word style (treating slashes and punctuation as boundaries) using either:
        *   *Method 1*: Load Zsh's built-in `select-word-style` utility in `programs.zsh.initContent`:
            ```bash
            autoload -Uz select-word-style
            select-word-style bash
            ```
        *   *Method 2*: Remove `/` and other characters from `WORDCHARS` in `programs.zsh.initContent`:
            ```bash
            export WORDCHARS='*?_-.[]~&;!#$%^(){}<>' # Note the absence of '/'
            ```

### 4.3 Shell Auto-suggestions
Auto-suggestions provide fish-like inline ghost text representing matching commands from shell history.

#### 4.3.1 Zsh Auto-suggestions
*   This is already implemented and working via:
    ```nix
    programs.zsh.autosuggestion.enable = true;
    ```
*   `modules/zsh/default.nix` also customizes the accept hotkey:
    ```bash
    bindkey '^E' autosuggest-accept # Accept with Ctrl+E
    ```
    This is a highly ergonomic and standard setup.

#### 4.3.2 Bash Auto-suggestions
Since standard GNU Readline does not support inline fish-like auto-suggestions natively, we recommend two options:

*   **Option A: Lighter, Native Readline History Search (Recommended for Simplicity)**:
    Instead of inline ghost suggestions, we configure Readline to perform prefix-based history searches when the user presses the **Up and Down arrow keys** (or custom keys). E.g., if the user types `git ` and presses Up, it cycles only through commands starting with `git `.
    This is incredibly lightweight, has zero dependencies, and is highly stable:
    ```nix
    programs.readline = {
      enable = true;
      bindings = {
        "\\e[A" = "history-search-backward"; # Up Arrow
        "\\e[B" = "history-search-forward";  # Down Arrow
      };
    };
    ```

*   **Option B: High-Performance Fish-Like Auto-suggestions with `ble.sh`**:
    If real-time, inline ghost suggestions are strictly required for Bash, we can enable **ble.sh** (Bash Line Editor). It replaces Readline with a pure Bash implementation of a modern command-line editor, enabling syntax highlighting, auto-suggestions, and more.
    ```nix
    programs.bash.blesh.enable = true;
    ```
    *Gotchas for `ble.sh`*:
    *   `ble.sh` completely bypasses GNU Readline, meaning any settings configured in `programs.readline` (including `Ctrl+W` custom bindings or `.inputrc`) may be ignored or overridden by `ble.sh`'s internal configuration.
    *   `ble.sh` can introduce minor startup latency on slow systems/remote environments.

---

## 5. Gotchas & Edge Cases

1.  **Double Semilinear Closes in `bash/default.nix`**:
    *   Existing lines 53-54 in `modules/bash/default.nix` have double `    '';`. The Coder must fix this syntax error before adding any configurations, as it will cause Nix evaluation to fail.
2.  **`stty` Override of `Ctrl+W`**:
    *   In many Linux distributions (and terminal emulators), `Ctrl+W` is bound at the terminal driver level to the `werase` command.
    *   If `stty` intercepts `Ctrl+W`, it never reaches GNU Readline. To ensure Readline-customized `Ctrl+W` behavior functions properly in Bash, we may need to explicitly unbind `werase` in the terminal. This is done by adding `stty werase undef` to `programs.bash.initExtra`.
3.  **`ble.sh` vs Readline**:
    *   If `programs.bash.blesh.enable = true;` is used, standard `.inputrc` configurations are ignored. The Coder must verify if custom `Ctrl+W` or prefix history keybindings need to be set using `ble.sh` native commands (e.g. `ble-bind`) within `initExtra` instead of `programs.readline`.

---

## 6. Needs Verification (Critical Checks)

The following behaviors must be verified at runtime by a Coder or user:

1.  **Terminal Driver Interception of `Ctrl+W`**:
    *   *Question*: Does pressing `Ctrl+W` in a standard shell session delete the last word out of the box, or does `stty werase` intercept it and prevent custom Readline bindings?
    *   *Verification*: The Coder should test if `Ctrl+W` works with and without `stty werase undef` inside `initExtra`.
2.  **Evaluation of `programs.bash.blesh.enable`**:
    *   *Question*: Does our current Home Manager channel support `programs.bash.blesh.enable` without errors? Is the `blesh` package successfully downloaded and activated?
    *   *Verification*: Run `build-and-switch` with `programs.bash.blesh.enable = true;` and verify if evaluation succeeds and if auto-suggestions show up in Bash.
3.  **Readline Up/Down Arrow Prefix Search**:
    *   *Question*: Are Up/Down Arrow escape sequences correctly mapped to `\e[A` and `\e[B` in the target terminal emulator?
    *   *Verification*: Verify keypress signals by running `cat` in the terminal, pressing Up/Down, and validating they produce `^[[A` and `^[[B`.

---

## 7. References

*   [Home Manager Zsh Options Documentation](https://home-manager-options.extranix.com/?query=programs.zsh)
*   [Home Manager Bash Options Documentation](https://home-manager-options.extranix.com/?query=programs.bash)
*   [Home Manager GNU Readline Documentation](https://home-manager-options.extranix.com/?query=programs.readline)
*   [NixOS Wiki: ble.sh Configuration](https://nixos.wiki/wiki/Bash)
*   [GNU Readline Bindings and Variables Guide](https://www.gnu.org/software/bash/manual/html_node/Readline-Init-File-Syntax.html)
