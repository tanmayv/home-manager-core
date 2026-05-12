# Reviewer Response — Tmux Scroll Wheel Alternate Screen Binding

## Verdict
**NEEDS_FIX**

## Approach Assessment
The overall approach of intercepting `WheelUpPane` and `WheelDownPane` and translating them into:
1. Pass-through mouse events if the app captures mouse (`mouse_any_flag`).
2. Pass-through mouse events if already in copy mode (`pane_in_mode`).
3. Arrow keys if in an alternate screen (`alternate_on`).
4. Entering copy-mode and scrolling otherwise.

is highly robust and correct. However, the implementation has severe syntax errors that prevent the bindings from functioning in a live Tmux session.

---

## Critical Findings

### 🔴 Critical: Invalid `-i` flag used in `if-shell`
*   **File & Line**: [modules/tmux/tmux-conf.nix:213](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/tmux/tmux-conf.nix#L213) and [modules/tmux/tmux-conf.nix:214](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/tmux/tmux-conf.nix#L214)
*   **Issue**: The `if-shell` command uses an invalid `-Fi` flag configuration. Tmux's `if-shell` does not support an `-i` flag (only `-F` and `-b`). When Tmux evaluates this configuration, it fails with:
    `command if-shell: unknown flag -i`
    As a result, the bindings are silently discarded and the default scrolling behavior is kept.
*   **Evidence**: Sourced the exact evaluated tmux configurations inside a live test server. The server threw:
    ```
    command if-shell: unknown flag -i
    command if-shell: unknown flag -i
    ```
    Running `list-keys -T root` confirmed the custom wheel bindings were not applied.
*   **How to Fix**: Change `-Fi` to `-F` on both lines:
    ```diff
    -        bind -n WheelUpPane if-shell -Fi -t= "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'if -Ft= \"#{alternate_on}\" \"send-keys -t= Up Up Up\" \"copy-mode -et=\"'"
    -        bind -n WheelDownPane if-shell -Fi -t= "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'if -Ft= \"#{alternate_on}\" \"send-keys -t= Down Down Down\"'"
    +        bind -n WheelUpPane if-shell -F -t= "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'if -Ft= \"#{alternate_on}\" \"send-keys -t= Up Up Up\" \"copy-mode -et=\"'"
    +        bind -n WheelDownPane if-shell -F -t= "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'if -Ft= \"#{alternate_on}\" \"send-keys -t= Down Down Down\"'"
    ```

---

## Reality Check

*   ✅ [modules/tmux/tmux-conf.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/tmux/tmux-conf.nix): Opened and verified lines 213-214.
*   ✅ Escaping Correctness: Verified that the Nix string evaluates backslashes and double quotes correctly. A Nix evaluation (`nix eval --raw`) correctly yielded:
    `if -Ft= '#{pane_in_mode}' 'send-keys -M' 'if -Ft= \"#{alternate_on}\" ...'`
    This is correctly parsed by Tmux (with the double quotes evaluated safely due to outer double-quotes).
*   ✅ Tmux Sourcing Test: Created a physical `test-tmux.conf` with the evaluated lines, initialized a new background Tmux test server instance, and executed `source-file`. Successfully reproduced the `-i` error, and verified that removing `-i` allows the config to load flawlessly.

---

## Verification Log

Files opened and checked:
1.  [modules/tmux/tmux-conf.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/tmux/tmux-conf.nix)
2.  [15_reviewer_tmux_scroll.md](file:///usr/local/google/home/tanmayvijay/home-manager-core/google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/prompts/15_reviewer_tmux_scroll.md) (Task file)
3.  [14_coder_tmux_scroll.md](file:///usr/local/google/home/tanmayvijay/home-manager-core/google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/14_coder_tmux_scroll.md) (Coder's self-report)
4.  [project_brief.md](file:///usr/local/google/home/tanmayvijay/home-manager-core/google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/project_brief.md) (Project brief)

---

## What's Missing

None. The implementation targets the correct files and contains all components of the plan, though buggy.

---

## Observations

*   **Approval Bias Warning**: The Coder's report confidently claimed success and syntax correctness because `nix-instantiate --parse` passed. This only verifies the *Nix wrapper syntax*, completely missing the Tmux-specific syntax error. Future agents should be instructed to test configs inside actual applications where possible, rather than relying solely on meta-compiler checks.
