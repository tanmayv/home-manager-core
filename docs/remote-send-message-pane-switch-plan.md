# Remote `send-message` pane switch implementation plan

## Goal

When a message sent by `agent-tracker-ctl send-message` arrives from a remote tracker, the receiving machine should not only notify the target local agent, but also switch tmux focus to that target agent's pane.

This should make remote-origin messages behave like an attention/hand-off action on the receiving host while preserving existing local-only send behavior.

## Current state

- Local CLI entrypoint: `modules/agent-tracker/ctl_commands/send_message.py`
- Local daemon RPC: `modules/agent-tracker/rpc_handler.py::handle_send_message`
- Shared local delivery path: `modules/agent-tracker/rpc_handler.py::deliver_local_message`
- Remote delivery path: `modules/agent-tracker/registry_client.py::_delivery_loop`
  - It receives queued registry deliveries.
  - It calls `deliver_local_message(...)` with message metadata including `sender_tracker_id`.
- Pane focusing already exists in `modules/agent-tracker/ctl_commands/focus.py` using:
  - `tmux switch-client -t <session>`
  - `tmux select-window -t <pane>`
  - `tmux select-pane -t <pane>`

## Proposed design

### 1. Add a reusable tmux focus helper

Add `focus_pane(pane_id, session=None, socket_path=None)` to `modules/agent-tracker/tmux_util.py`.

Behavior:

1. Build the tmux command prefix, honoring `socket_path` when present.
2. If `session` is present, run `tmux switch-client -t <session>` best-effort.
3. Run `tmux select-window -t <pane_id>` best-effort.
4. Run `tmux select-pane -t <pane_id>` best-effort.
5. Log failures, but do not fail message delivery.

### 2. Detect remote-origin deliveries in `deliver_local_message`

In `rpc_handler.deliver_local_message`, detect remote-origin messages via:

```python
is_remote_origin = bool(
    msg_obj.get("sender_tracker_id")
    and msg_obj.get("sender_tracker_id") != registry_client.TRACKER_ID
)
```

After the inbox write and notification event publication, if `is_remote_origin` is true and target agent info has a `tmux_pane`, call:

```python
tmux_util.focus_pane(info.get("tmux_pane"), info.get("session"), info.get("tmux_socket"))
```

This puts the behavior at the shared delivery layer, so it covers:

- registry queued deliveries from remote `send-message`
- any future remote delivery path that preserves `sender_tracker_id`

### 3. Keep behavior scoped to remote-origin messages

Do **not** switch panes for ordinary local sends:

- `agent-tracker-ctl send-message local-agent "..."`
- `agent-communicator` sending to a local agent

Only remote-origin messages should trigger pane switching.

### 4. Make focus failure non-fatal

Pane switching should never prevent message delivery. Missing/closed panes, stale sessions, or tmux errors should log warnings only.

### 5. Optional config toggle if focus stealing is too aggressive

If needed, add an environment/module option later:

- `services.agent-tracker.switchToPaneOnRemoteMessage = true;`
- env: `AGENT_TRACKER_SWITCH_ON_REMOTE_MESSAGE=true`

Initial implementation can default to enabled to match the requested behavior.

## Test plan

### Unit tests

1. `tmux_util` focus helper test
   - Mock `subprocess.run`.
   - Verify tmux commands include socket prefix when provided.
   - Verify it attempts `switch-client`, `select-window`, and `select-pane`.

2. `rpc_handler.deliver_local_message` remote-origin test
   - Set up a target agent with `tmux_pane`, `session`, and `tmux_socket`.
   - Deliver a message with `sender_tracker_id != registry_client.TRACKER_ID`.
   - Assert `tmux_util.focus_pane` was called once.

3. Local-origin regression test
   - Deliver a message with no `sender_tracker_id`, or local `sender_tracker_id`.
   - Assert `tmux_util.focus_pane` was not called.

4. Failure tolerance test
   - Mock `focus_pane` to raise.
   - Assert delivery still succeeds and inbox is written.

### Manual validation

1. Start two trackers/hosts connected through the registry.
2. From remote host:

```bash
agent-tracker-ctl send-message <local-host>/<local-agent> "hello from remote"
```

3. On the receiving machine, verify:
   - target agent inbox gets the message
   - notification still appears
   - tmux client switches to the target agent pane

## Implementation order

1. Add `tmux_util.focus_pane`.
2. Add remote-origin detection and best-effort focus call in `deliver_local_message`.
3. Add/adjust tests.
4. Run targeted tests:

```bash
python3 -m pytest modules/agent-tracker/test_tmux_util.py modules/agent-tracker/test_rpc_handler.py
```

5. Run broader agent-tracker tests if targeted tests pass.
6. Rebuild/apply Home Manager and validate with a remote send.
