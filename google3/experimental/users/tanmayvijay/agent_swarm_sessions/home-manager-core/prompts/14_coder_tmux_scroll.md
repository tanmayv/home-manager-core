# Prompt 14: Coder — Tmux Scroll Wheel Alternate Screen Binding

**Persona:** Read `google3/experimental/users/goldental/agent_swarm/personas/coder/coder.md` — that defines your role. Read
`google3/experimental/users/goldental/agent_swarm/common/swarm_protocol.md` — shared rules for all agents.

**Input:** Read ALL of these before starting:
- [modules/tmux/tmux-conf.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/tmux/tmux-conf.nix)

**Response:** Write to `google3/experimental/users/tanmayvijay/agent_swarm_sessions/home-manager-core/responses/14_coder_tmux_scroll.md`

--------------------------------------------------------------------------------

## Mission

Configure `tmux` so that using the mouse scroll wheel in TUI applications that do not natively support mouse events (like Jetski) scrolls the application using Arrow keys rather than hijacking history and entering copy-mode.

Specifically:
Modify [modules/tmux/tmux-conf.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/tmux/tmux-conf.nix) to add custom bindings for `WheelUpPane` and `WheelDownPane` in `extraConfig` right after `set -g mouse on` (line 210).

These bindings will check:
1. If the application natively listens to mouse events (like Vim with mouse reporting), pass raw scroll wheel event (`send-keys -M`).
2. If the pane is already in copy-mode, pass the raw event (`send-keys -M`).
3. If in alternate screen mode (TUI active) and NOT capturing mouse, translate wheel scroll into `Up` / `Down` arrow keys to scroll the TUI app interface.
4. If in standard terminal mode, enter copy-mode (`copy-mode -et=`).

--------------------------------------------------------------------------------

## Tasks

1.  Modify [modules/tmux/tmux-conf.nix](file:///usr/local/google/home/tanmayvijay/home-manager-core/modules/tmux/tmux-conf.nix):
    *   Find:
        ```tmux
                set -g mouse on
        ```
    *   Insert the following bindings immediately underneath:
        ```tmux
                # Scroll in alternate screen (TUI apps like less, vim, jetski) using Up/Down arrow keys instead of entering copy-mode
                bind -n WheelUpPane if-shell -Fi -t= "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'if -Ft= \"#{alternate_on}\" \"send-keys -t= Up Up Up\" \"copy-mode -et=\"'"
                bind -n WheelDownPane if-shell -Fi -t= "#{mouse_any_flag}" "send-keys -M" "if -Ft= '#{pane_in_mode}' 'send-keys -M' 'if -Ft= \"#{alternate_on}\" \"send-keys -t= Down Down Down\"'"
        ```
2.  Verify syntax by running:
    ```bash
    nix-instantiate --parse /usr/local/google/home/tanmayvijay/home-manager-core/modules/tmux/tmux-conf.nix
    ```

--------------------------------------------------------------------------------

## Deliverables

Write your response per the format defined in your persona.
