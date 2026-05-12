# Prompt 14 (Fix 1): Coder — Correct Tmux Scroll Bindings Syntax

**Persona:** Read `google3/experimental/users/goldental/agent_swarm/personas/coder/coder.md` — that defines your role. Read
`google3/experimental/users/goldental/agent_swarm/common/swarm_protocol.md` — shared rules for all agents.

**Input:** Read ALL of these before starting:
- [modules/tmux/tmux-conf.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/tmux/tmux-conf.nix)
- `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/15_reviewer_tmux_scroll.md` — the Reviewer's design audit feedback

**Response:** Write to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/14_coder_tmux_scroll_fix_1.md`

--------------------------------------------------------------------------------

## Mission

The Reviewer returned a **NEEDS_FIX** verdict because of a critical syntax defect in the Tmux scroll bindings you added.

### The Issue
The `if-shell` command inside the `WheelUpPane` and `WheelDownPane` bindings uses an invalid `-Fi` flag.
Tmux does **not** support a `-i` flag on `if-shell` (it only supports `-F` and `-b`).
Because of this, when Tmux loads, it fails with `unknown flag -i` and discards the custom wheel scroll bindings completely, keeping the default scrolling behavior.

### The Solution
Modify [modules/tmux/tmux-conf.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/tmux/tmux-conf.nix) to change `-Fi` to `-F` inside the `WheelUpPane` and `WheelDownPane` keybindings.

--------------------------------------------------------------------------------

## Nix Diff Specification for the Fix

Ensure your modifications are exactly as follows:

```diff
@@ -210,4 +210,4 @@
         set -g mouse on
 
         # Scroll in alternate screen (TUI apps like less, vim, jetski) using Up/Down arrow keys instead of entering copy-mode
-        bind -n WheelUpPane if-shell -Fi -t= "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'if -Ft= \"#{alternate_on}\" \"send-keys -t= Up Up Up\" \"copy-mode -et=\"'"
-        bind -n WheelDownPane if-shell -Fi -t= "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'if -Ft= \"#{alternate_on}\" \"send-keys -t= Down Down Down\"'"
+        bind -n WheelUpPane if-shell -F -t= "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'if -Ft= \"#{alternate_on}\" \"send-keys -t= Up Up Up\" \"copy-mode -et=\"'"
+        bind -n WheelDownPane if-shell -F -t= "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'if -Ft= \"#{alternate_on}\" \"send-keys -t= Down Down Down\"'"
```

--------------------------------------------------------------------------------

## Tasks

1.  Modify [modules/tmux/tmux-conf.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/tmux/tmux-conf.nix) to correct the flags.
2.  Verify syntax by running:
    ```bash
    nix-instantiate --parse /usr/local/google/home/tanmayvijay/home-manager-core/modules/tmux/tmux-conf.nix
    ```
