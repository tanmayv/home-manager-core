# Project Brief

## Goal

Fix tab completion, configure `Ctrl+W` to delete a word, and enable shell auto-suggestions in both Bash and Zsh configurations within the Home Manager setup.

## Requirements

*   **Tab Completion**:
    *   Ensure tab completion is set up and functioning correctly in both Zsh and Bash.
*   **Word Deletion**:
    *   Map `Ctrl+W` (`C-w`) to delete the last word in both Zsh and Bash (standard behavior, ensuring it doesn't delete up to the slash or other custom boundaries unless expected by standard readline/zsh line editor).
*   **Auto Suggestions**:
    *   Enable auto-suggestions (e.g., `zsh-autosuggestions` for Zsh, and standard equivalent or package for Bash if available/supported).

## Pointers

*   [modules/bash/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/bash/default.nix)
*   [modules/zsh/default.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/zsh/default.nix)

## Success Criteria

*   Tab completion works out-of-the-box after building and switching configuration.
*   Pressing `Ctrl+W` in Bash and Zsh deletes the last word.
*   Auto-suggestions display matches from shell history as you type in both shells.

## Constraints

*   Must be managed cleanly via Home Manager configurations.
*   Must build successfully using `build-and-switch`.
