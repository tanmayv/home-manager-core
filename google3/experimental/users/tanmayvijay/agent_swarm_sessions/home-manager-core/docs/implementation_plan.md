# Implementation Plan — Shell Enhancements

This document outlines a detailed implementation plan for improving tab completion, word deletion (`Ctrl+W`), and shell suggestions across Bash and Zsh inside the Minimal Cloudtop Home Manager configuration.

---

## 1. Problem Statement

The end users are Google DeepMind researchers utilizing standard shell environments (Bash and Zsh) on their Cloudtops. In the current state, they face three major productivity bottlenecks:
1. **Tab Completion**: Shell completions are either unconfigured or inconsistently enabled, meaning standard CLI tool completions (like `git`, `g4`, etc.) do not work out-of-the-box.
2. **Inconsistent Word Deletion (`Ctrl+W`)**: In Bash, pressing `Ctrl+W` deletes an entire whitespace-separated segment (e.g., `/usr/local/bin` deletes the whole path), while in Zsh, it does the same due to a broad definition of word boundaries. The user desires a consistent, sub-word stop behavior where pressing `Ctrl+W` stops at directory slashes and punctuation (e.g., deleting `bin`, then `local`, then `usr`).
3. **Lack of Bash Suggestions**: While Zsh is already configured with auto-suggestions, Bash has no history suggestion mechanism, requiring users to type long commands repeatedly.

Additionally, a syntax error (duplicate closing `    '';` tags) in [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix#L53-L54) prevents Nix evaluation, acting as a hard blocker for any configuration changes.

---

## 2. Approach Justification

The chosen strategic approach balances usability, lightweight footprint, and maximum stability:

*   **Bash Auto-suggestions via Readline Prefix History Search (Option A)**:
    *   *Why it fits*: Instead of using heavy wrappers like `ble.sh` (which completely bypass GNU Readline and override other keymaps), we configure the standard Readline `history-search-backward` and `history-search-forward` functions. This is built-in, stable, has zero dependencies, and has zero impact on shell startup time.
    *   *Mitigation*: Typing a prefix and pressing Up/Down arrow keys behaves predictably and avoids conflicts with history tools like `Atuin`.
*   **Consistent Sub-word Stop boundaries for `Ctrl+W` (Option B)**:
    *   *Why it fits*: Mapping `Ctrl+W` to `backward-kill-word` in Readline (for Bash) and loading `select-word-style bash` in Zsh align both shells to treat punctuation and slashes as word boundaries. This makes navigating complex directory paths and URL structures much faster.
    *   > [!NOTE]
    *   > **Pivot from Solutions Brief**: The *Solutions Brief* originally recommended Option A (Whitespace boundaries) for word deletion to maintain standard Unix defaults. However, during strategic selection, the user explicitly requested Option B (Sub-word boundaries). Therefore, this plan pivots to Option B to treat punctuation and directory slashes as word boundaries.
*   **Explicit Completion Enablement**:
    *   *Why it fits*: Declaring `programs.bash.enableCompletion = true;` and `programs.zsh.enableCompletion = true;` guarantees that Home Manager sets up and sources completion files correctly on generic Linux targets without relying on implicit defaults.

---

## 3. Technical Overview

The configuration is structured as a Nix-based Home Manager setup with separate modules for each shell. 

### Current State & Shortcuts
*   **Bash**: Configuration is defined in [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix).
    *   Contains `programs.bash` attribute set.
    *   Contains basic aliases and environment setups.
    *   Integrates with `zoxide` and `atuin`.
    *   **Shortcoming**: A duplicate `    '';` closing string blocks compilation.
*   **Zsh**: Configuration is defined in [modules/zsh/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/zsh/default.nix).
    *   Contains `programs.zsh` attribute set.
    *   `programs.zsh.autosuggestion.enable = true;` is already set.
    *   `initContent` configures keymaps (`Ctrl+E`, `Ctrl+P`, `Ctrl+N`).
    *   **Shortcoming**: Lacks explicit `enableCompletion = true;` declaration and has whitespace-delimited `Ctrl+W` boundaries.

### Major System Connections & Key Abstractions
The changes operate purely on standard Home Manager configurations:
*   `programs.bash` and `programs.zsh` are the standard entries for configuring the respective shells.
*   `programs.readline` controls the `~/.inputrc` file used by GNU Readline (Bash's editor).
*   `zsh-autosuggestions` and ZLE (Zsh Line Editor) control Zsh's behavior.

```
                 +----------------------------------+
                 | Home Manager Nix Configurations  |
                 +-----------------+----------------+
                                   |
         +-------------------------+-------------------------+
         |                                                   |
         v                                                   v
+------------------------+                          +------------------------+
| modules/bash/default.nix|                          | modules/zsh/default.nix|
+--------+---------------+                          +--------+---------------+
         |                                                   |
         v                                                   v
+------------------------+                          +------------------------+
| GNU Readline           |                          | Zsh Line Editor (ZLE)  |
| - Tab Completion       |                          | - Tab Completion       |
| - Up/Down Prefix       |                          | - select-word-style    |
| - Ctrl+W Sub-word Stop |                          | - Ctrl+W Sub-word Stop |
+------------------------+                          +------------------------+
```

---

## 4. File Manifest

The following files are modified to implement this enhancement:

File | Action | Rationale | Dependencies
--- | --- | --- | ---
[modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix) | Modify | 1. Fix syntax defect (duplicate closing string).<br>2. Enable Bash tab completion (`enableCompletion = true`).<br>3. Add GNU Readline prefix search and sub-word Ctrl+W bindings.<br>4. Disable Atuin's Up-arrow override (`enable_up_arrow = false`) to allow native GNU Readline prefix history search to function. | None
[modules/zsh/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/zsh/default.nix) | Modify | 1. Explicitly enable Zsh tab completion.<br>2. Load `select-word-style bash` in `initContent` to enable sub-word stop. | None

---

## 5. Phase 0: Assumption Validation / Test Spike

Before executing the changes, we must perform validation checks to ensure the terminal driver does not intercept keypresses or conflict with Readline.

### Step 0.1: Verify Escape Sequences for Up/Down Arrows
Standard terminal emulators map Up Arrow to `\e[A` and Down Arrow to `\e[B`.
*   **Action**: Run `cat` in your terminal and press Up and Down.
*   **Expected Output**:
    *   Up Arrow should output `^[[A`
    *   Down Arrow should output `^[[B`
*   **If it fails**: If they map to different characters (e.g., application mode `^[OA` / `^[OB`), we must update the GNU Readline bindings configuration accordingly.

### Step 0.2: Verify `stty werase` Interception
In some operating systems, the terminal driver processes `Ctrl+W` at the line discipline level before passing it to Bash.
*   **Action**: Run the command:
    ```bash
    stty -a | grep werase
    ```
*   **Expected Output**: Check if `werase = ^W` is shown.
*   **Evaluation**:
    *   If `werase` is bound to `^W`, the terminal driver might intercept `Ctrl+W` in canonical mode.
    *   However, since Bash/Readline runs in raw mode, this is usually bypassed. If manual validation shows `Ctrl+W` still deletes whole words even after applying the bindings in Chunk 2, we will add `stty werase undef` to `programs.bash.initExtra`.

---

## 6. Implementation Chunks

---

### Chunk 1: Syntax defect fix in `modules/bash/default.nix`

Fix the duplicate closing quotes `'';` that prevents the Nix configuration from evaluating.

#### Files to Modify
*   [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix) (Lines 53-54)

#### Nix Configuration Changes
```diff
@@ -50,6 +50,5 @@
         tmux-sessionizer
       fi
       '' else ""}
     '';
-    '';
   };
```

#### Validation Steps
1. Run the Nix parsing parser dry-run to confirm correct syntax:
   ```bash
   nix-instantiate --parse /usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix
   ```
2. Verify it exits successfully without syntax errors.

---

### Chunk 2: Configure Bash tab completion, prefix-based history suggestions, and sub-word word-deletion boundaries via GNU Readline

Configure GNU Readline to map `Ctrl+W` to sub-word deletion and Up/Down arrows to prefix history search. Explicitly enable Bash standard completion. Configure Atuin to release control of Up/Down arrows.

#### Files to Modify
*   [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix)

#### Nix Configuration Changes
```diff
@@ -12,6 +12,7 @@
 
   programs.bash = {
     enable = true;
+    enableCompletion = true;
     shellAliases = {};
 
     initExtra = ''
@@ -52,6 +53,16 @@
       '' else ""}
     '';
   };
+
+  programs.readline = {
+    enable = true;
+    bindings = {
+      "\\e[A" = "history-search-backward";
+      "\\e[B" = "history-search-forward";
+      "\\C-w" = "backward-kill-word";
+    };
+  };
 
   programs.zoxide = {
     enable = true;
@@ -64,6 +75,7 @@
     enableBashIntegration = true;
     settings = {
       auto_sync = false;
       search_mode = "fuzzy";
+      enable_up_arrow = false;
     };
   };
 }
```

#### Validation Steps
1. Apply the changes by running:
   ```bash
   build-and-switch
   ```
2. Open a new Bash session.
3. **Verify Tab Completion**:
   Type `git ` and press Tab. It should show autocomplete choices or suggestions.
4. **Verify Prefix History Search**:
   * Type `ls` and execute a few commands (e.g., `ls -la`, `ls -t`, `echo hello`).
   * In a new line, type `ls` (do not press enter) and press **Up Arrow**. It should only cycle through `ls -la` and `ls -t`, ignoring `echo hello`.
   * Pressing **Ctrl+R** should still correctly invoke Atuin's interactive history UI.
5. **Verify Ctrl+W sub-word boundaries**:
   * Type `/usr/local/bin` and press `Ctrl+W`.
   * **Pass criteria**: The cursor deletes `bin` leaving `/usr/local/`. Pressing it again deletes `local`, leaving `/usr/`.
   * **Fail criteria**: The entire `/usr/local/bin` is deleted at once.

---

### Chunk 3: Configure Zsh tab completion and sub-word word-deletion boundaries

Explicitly enable Zsh completions and load the Zsh built-in `select-word-style` with `bash` style to enable sub-word deletion.

#### Files to Modify
*   [modules/zsh/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/zsh/default.nix)

#### Nix Configuration Changes
```diff
@@ -40,9 +40,14 @@
 
   programs.zsh = {
     enable = true;
+    enableCompletion = true;
     dotDir = "${config.xdg.configHome}/zsh";
     autosuggestion.enable = true;
     syntaxHighlighting.enable = true;
     shellAliases = myAliases;
 
     initContent = ''
       zmodload zsh/nearcolor
       export COLORTERM=truecolor
 
+      # Enable Bash-style sub-word deletion boundaries (stops at slashes, etc.)
+      autoload -Uz select-word-style
+      select-word-style bash
+
       # Accept autosuggestion with Ctrl+E
```

#### Validation Steps
1. Apply the changes:
   ```bash
   build-and-switch
   ```
2. Open a new Zsh session.
3. **Verify Zsh Completion**:
   Type `git ` and press Tab. It should display completions.
4. **Verify Zsh Ctrl+W sub-word boundaries**:
   * Type `/usr/local/bin` and press `Ctrl+W`.
   * **Pass criteria**: The cursor deletes `bin` leaving `/usr/local/`.
   * **Fail criteria**: The entire path is deleted at once.

---

## 7. Spec Self-Check

1.  **Purpose Test**: Yes. The Problem Statement clearly explains the enhancements required (completion, Ctrl+W subword deletion, auto-suggestions), the user pain points, and why this improves their workflow.
2.  **System Test**: Yes. The Technical Overview describes modules, files, and abstractions mapped directly to the user's environment.
3.  **Implementation Test**: Yes. The exact chunks provide direct copy-pasteable diffs and step-by-step instructions. No additional context is needed.
