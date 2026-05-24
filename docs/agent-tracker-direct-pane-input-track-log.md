# Agent Tracker Direct Pane Input Track Log

## Feature
Add direct pane input functionality to `agent-tracker` and `agent-registry`:

- `agent-tracker-ctl send-text TARGET "text"`: type literal text into the target agent pane and submit with Enter by default, bypassing inbox.
- `agent-tracker-ctl send-key TARGET KEY [KEY...]`: send tmux key tokens such as `Escape`, `Enter`, `C-c` directly to the target agent pane, bypassing inbox.
- Support the same local and remote target syntax as `send-message`, including `host/agent` and `registry:host/agent`.

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
Status: Pending
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

### Chunk 2 — CLI commands
Status: Pending
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

### Chunk 3 — Registry protocol for remote pane input
Status: Pending
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

### Chunk 4 — Remote delivery loop dispatch
Status: Pending
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

### Chunk 5 — Safety controls, docs, final tests
Status: Pending
Owner: Coder
Reviewer: Reviewer

Scope:
- Add opt-out/config guardrails if needed.
- Add audit logging without leaking full text payloads.
- Update README/USAGE docs.
- Run broad test suite.

Acceptance:
- Remote direct input can be disabled or clearly guarded.
- Documentation includes local and remote examples.
- Relevant Python tests pass.

## Timeline

- 2026-05-25: Lead created feature branch `feature/agent-tracker-direct-pane-input`, spawned coder/reviewer agents, and initialized this track log.
