# Agent Tracker Direct Pane Input Track Log

## Feature
Add direct pane input functionality to `agent-tracker` and `agent-registry`:

- `agent-tracker-ctl send-text TARGET "text"`: type literal text into the target agent pane and submit with Enter by default, bypassing inbox.
- `agent-tracker-ctl send-key TARGET KEY [KEY...]`: send tmux key tokens such as `Escape`, `Enter`, `C-c` directly to the target agent pane, bypassing inbox.
- Support the same local and remote target syntax as `send-message`, including `host/agent` and `registry:host/agent`.
- After `agent-tracker` and `agent-registry` backend support is working, update `agent-communicator-tui` so its input/composer can use existing `send-message` plus new `send-text` and `send-key` actions.

## Roles

- Lead: `home-manager-core-agent-1`
  - Owns chunk sequencing, acceptance, track-log consistency, and final integration.
- Coder: `hm-core-keyinput-coder`
  - Implements one assigned chunk at a time.
  - Updates this log with implementation notes and test results.
  - Does not start the next chunk until current chunk is reviewed and committed.
- Reviewer: `hm-core-keyinput-reviewer`
  - Reviews each chunk after coder signals readiness.
  - Runs or inspects relevant tests.
  - Reports approval/blockers to lead and coder.
  - Avoids feature edits except small review notes if explicitly requested.

## Chunk Workflow

For every chunk:

1. Lead assigns exactly one chunk to coder.
2. Coder implements the chunk and updates this log under the chunk section.
3. Coder notifies reviewer and lead that the chunk is ready.
4. Reviewer reviews diff/tests and sends either approval or requested changes.
5. Coder addresses review comments if any.
6. Once approved, coder commits the chunk with a focused commit message.
7. Coder asks lead for the next chunk automatically.

## Implementation Plan / Chunks

### Chunk 1 — Local pane input primitives and RPC
Status: Completed
Commit: `661b962 agent-tracker: add local direct pane input RPC`
Owner: Coder
Reviewer: Reviewer

Scope:
- Add safe tmux helpers for literal text and symbolic key input.
- Add RPC handler for local `send_input` / direct pane input.
- Add unit tests for helper behavior and RPC local delivery.

Acceptance:
- Literal text uses tmux literal mode and optional submit Enter.
- Key mode supports aliases like `ESC`, `ENTER`, `C-C` and rejects unsafe invalid tokens.
- Local RPC resolves target by name/ID and bypasses inbox.
- Existing `send-message` tests remain passing.

Implementation notes:
- Added `tmux_util.send_literal_text()` using `tmux send-keys -l` plus optional `Enter` submit.
- Added `tmux_util.send_symbolic_keys()` with normalization for aliases and modifier tokens, rejecting whitespace/shell-like unsafe tokens.
- Added local `rpc_handler.handle_send_input()` and dispatcher wiring for text/key direct pane input.
- Local `target_address` (`local/name` or local hostname) resolves locally; remote direct input intentionally remains unimplemented for later chunks.

Tests:
- `cd modules/agent-tracker && python -m unittest test_tmux_util.py test_rpc_handler.py` — OK (55 tests)
- `cd modules/agent-tracker && python -m unittest test_send_message_verify.py test_agent_tracker_ctl.py` — OK (17 tests)

Review follow-up:
- Added `--` separator before literal text (`tmux send-keys -l -- TEXT`) so text beginning with `-` is not parsed as tmux options.
- Added regression coverage for literal `-n` and rejection of malformed trailing modifier key token `C-`.
- Reran `cd modules/agent-tracker && python -m unittest test_tmux_util.py test_rpc_handler.py test_send_message_verify.py test_agent_tracker_ctl.py` — OK (73 tests)

### Chunk 2 — CLI commands
Status: Completed
Commit: `982a68f agent-tracker: add direct input CLI commands`
Owner: Coder
Reviewer: Reviewer

Scope:
- Add `send-text` command.
- Add `send-key` command.
- Register commands in `agent-tracker-ctl.py`.
- Add CLI parsing tests and help text.

Acceptance:
- `agent-tracker-ctl send-text alice "hello"` calls RPC with text + submit.
- `agent-tracker-ctl send-text --no-submit alice "draft"` does not submit.
- `agent-tracker-ctl send-key alice ESC C-c Enter` calls RPC with normalized/requested keys.

Implementation notes:
- Added `ctl_commands/send_text.py` and `ctl_commands/send_key.py` commands that call `send_input` RPC with `input_type=text|keys`.
- Registered both commands in `agent-tracker-ctl.py` and added top-level help examples.
- Target selection mirrors `send-message`: bare names map to `agent_name`, UUIDs map to `agent_id`, and host-qualified targets pass through as `target_address` for later remote support.

Tests:
- `cd modules/agent-tracker && python -m unittest test_agent_tracker_ctl.py test_send_message_verify.py test_rpc_handler.py test_tmux_util.py` — OK (80 tests)
- `git diff --check` — OK

### Chunk 3 — Registry protocol for remote pane input
Status: Completed
Commit: `b20ee00 agent-registry: queue direct pane input deliveries`
Owner: Coder
Reviewer: Reviewer

Scope:
- Add registry endpoint for pane input queueing, separate from `/messages`.
- Add registry client sender helpers.
- Preserve `/messages` behavior unchanged.
- Add registry HTTP tests.

Acceptance:
- Remote pane input queues as a distinct delivery type.
- Target resolution and stale/offline handling mirror `/messages`.
- Invalid payloads are rejected.

Implementation notes:
- Added `POST /pane-inputs` to `agent-registry`, queueing deliveries with `delivery_type: pane_input` while keeping `/messages` unchanged.
- Added pane-input validation for target, `input_type=text|keys`, text payloads, key-token lists, and text-only `submit`.
- Added `registry_client` helpers for default/explicit registry pane-input routing and wired remote `handle_send_input()` target addresses to them.
- Registry delivery polling leaves queued `pane_input` deliveries unacked/deferred until Chunk 4 dispatch support is implemented.

Tests:
- `cd modules/agent-tracker && python -m unittest test_http_registry.py test_registry_client_routing.py test_rpc_handler.py test_agent_tracker_ctl.py test_tmux_util.py` — OK (108 tests)
- `git diff --check` — OK

Review follow-up:
- Added type validation for `/pane-inputs` lookup fields before registry dict lookups/comparisons: non-null `target_agent_id`, `target_agent_name`, `target_hostname`, and `sender_tracker_id` must be strings.
- Added regression tests that malformed authenticated requests with non-string lookup fields return JSON 400 instead of disconnecting.
- Reran `cd modules/agent-tracker && python -m unittest test_http_registry.py test_registry_client_routing.py test_rpc_handler.py test_agent_tracker_ctl.py test_tmux_util.py` — OK (109 tests)
- Reran `git diff --check` — OK

### Chunk 4 — Remote delivery loop dispatch
Status: Completed
Commit: `179c79a agent-tracker: deliver remote pane input`
Owner: Coder
Reviewer: Reviewer

Scope:
- Update registry delivery loop to dispatch pane-input deliveries to local tmux pane input instead of inbox.
- Ack only after local input succeeds.
- Add delivery-loop tests.

Acceptance:
- Remote `send-text host/agent "hello"` bypasses inbox and injects into pane.
- Remote `send-key host/agent C-c` sends key to pane.
- Transient local failures do not ack delivery.

Implementation notes:
- Added `rpc_handler.deliver_local_pane_input()` to validate and inject queued pane input by local target agent ID.
- Updated registry delivery loop to dispatch `delivery_type=pane_input` to direct pane input instead of inbox delivery.
- Pane-input deliveries ack only after local tmux input succeeds; invalid pane-input deliveries are acked/dropped, and transient tmux failures are retried without ack.
- Existing message delivery path remains unchanged.

Tests:
- `cd modules/agent-tracker && python -m unittest test_http_registry.py test_rpc_handler.py test_tmux_util.py test_registry_client_routing.py test_agent_tracker_ctl.py` — OK (112 tests)

### Chunk 5 — Safety controls and backend docs/tests
Status: Pending
Owner: Coder
Reviewer: Reviewer

Scope:
- Add opt-out/config guardrails if needed.
- Add audit logging without leaking full text payloads.
- Update backend CLI/registry docs.
- Run broad backend test suite.

Acceptance:
- Remote direct input can be disabled or clearly guarded.
- Backend documentation includes local and remote CLI examples.
- Relevant Python tests pass.

### Chunk 6 — Agent communicator TUI direct input actions
Status: Pending
Owner: Coder
Reviewer: Reviewer

Scope:
- Update `agent-communicator-tui` input/composer workflow to support choosing between:
  - `send-message` (existing inbox delivery),
  - `send-text` (literal direct pane input, submit by default),
  - `send-key` (direct symbolic key tokens).
- Wire TUI actions through the tracker client once backend commands/RPC are available.
- Preserve existing default send-message behavior unless the user explicitly selects direct input.
- Add Go tests for mode selection, command dispatch, local/remote target preservation, and regression coverage for existing message send.

Acceptance:
- Users can send inbox messages as before.
- Users can send direct text and direct keys from the TUI to local and remote targets supported by the backend.
- Existing communicator tests pass.

## Timeline

- 2026-05-25: Lead created feature branch `feature/agent-tracker-direct-pane-input`, spawned coder/reviewer agents, and initialized this track log.
- 2026-05-25: Chunk 1 completed and committed as `661b962` after reviewer approval. Lead added later-scope requirement for `agent-communicator-tui` direct input actions.
- 2026-05-25: Chunks 2, 3, and 4 completed and committed as `982a68f`, `b20ee00`, and `179c79a` after reviewer approval.
