# agent-communicator implementation plan

## Goal

Create a responsive Go terminal UI for agent-to-agent communication. The app lists local agents from `agent-tracker` and remote agents from `agent-registry`, lets the user select an agent, view a conversation-style message history, send Markdown messages, attach files, and open received attachments in a tmux popup with Neovim.

Reference mock: `docs/agent-communicator-mock.html`.

## Constraints

- Keep implementation chunks under 300 LOC before review.
- Use Go best practices: small packages, typed clients, context-aware IO, table-driven tests.
- Prefer Charmbracelet ecosystem for terminal UI: Bubble Tea for app loop, Lip Gloss for layout, Glamour for Markdown rendering. If the project specifically needs `gum`, use `gum` as an optional external helper for file picking/confirmation rather than blocking the core TUI on subprocesses.
- TUI must remain responsive: no network/socket calls in render path; use commands/goroutines and model messages.
- Update `TASKS.md` as phases complete.

## Current backend fit/gaps

Existing support:

- Local tracker JSON-RPC over Unix socket.
- Local `list`, `send-message`, `read-inbox` support.
- Remote registry `GET /agents` and queued `POST /messages` delivery.
- Attachments already use base64 input and are persisted to inbox attachment paths on delivery.

Gaps to close:

- Agent `cwd` is not currently exposed by tracker/registry snapshots.
- Messages do not have an explicit `content_type` / message type field yet.
- Conversation history is receiver-inbox oriented; sent-message history for the communicator should be stored locally.
- The communicator should be able to run as `cli-user` without registering as an agent, but responses require a known return target. Phase 1 can display messages from the current agent inbox when launched inside an agent pane; later phases can add an explicit communicator identity.

## Phase 0: design review and scaffolding

Deliverables:

- Review this plan.
- Binary/package location is fixed: `agent-communicator-tui/` as a standalone flake application.
- Confirm whether to use Bubble Tea directly with Charmbracelet styling or require shelling out to `gum` for specific interactions.

Tests:

- None beyond documentation review.

Review gate: required before code.

## Phase 1: Go module skeleton and typed clients

Deliverables:

- Add Go package skeleton under `agent-communicator-tui/`.
- Add `agent-communicator-tui/flake.nix` exposing:
  - `packages.${system}.default`
  - `apps.${system}.default`
  - `checks.${system}.default` running Go tests
- Design the standalone flake so the parent `home-manager-core` flake can consume it without duplicating packaging logic.
- `client/tracker`: Unix socket JSON-RPC client with methods:
  - `List(ctx)`
  - `SendMessage(ctx, target, message, attachments)`
  - `ReadInbox(ctx, opts)`
- `client/registry`: HTTP client with:
  - `ListAgents(ctx)`
- Shared models:
  - `Agent`
  - `Message`
  - `Attachment`
  - `MessageType`

Testing:

- Unit tests with fake Unix socket server for JSON-RPC.
- Unit tests with `httptest.Server` for registry parsing.
- Timeout/context cancellation tests.

Review gate: after skeleton + clients, under 300 LOC chunks.

## Phase 2: read-only responsive TUI

Deliverables:

- Bubble Tea model with three regions:
  - agent list
  - message viewport
  - selected-agent metadata
- Periodic refresh command for local and remote agents.
- Use tracker `wait_events` only as a best-effort wake-up signal; on startup, `reset`, `gap`, timeout, and periodic fallback, reload durable inbox/history.
- Set Go Unix socket deadlines longer than the requested long-poll timeout, e.g. `timeout + 5s`, because `agent-tracker-ctl`'s 5s default is too short for 25s waits.
- Keyboard navigation:
  - up/down select agent
  - tab cycle focus
  - q quit
- Markdown rendering for message bodies using Glamour.
- Show `cwd` field when available, fallback to `unknown`.

Testing:

- Model update tests for navigation and refresh messages.
- View snapshot/golden tests for narrow and wide terminal sizes.

Review gate: read-only TUI usable before sending logic.

## Phase 3: backend cwd propagation

Deliverables:

- Add `cwd` to local tracker state where possible:
  - registration params from wrapper/managed-agent if available
  - recovery via tmux pane current path if feasible
- Include `cwd` in `get_agents_for_registry()` snapshots.
- Preserve compatibility when `cwd` is absent.
- Update Nix/module plumbing only if a user-facing option is added. If adding setup flags, update `docs/Customization.md`.

Testing:

- `test_state.py` for registry-safe snapshot includes `cwd`.
- RPC/register tests for cwd persistence.
- Registry tests for cwd roundtrip in `/agents`.

Review gate: backend change reviewed independently because it affects tracker/registry protocols.

## Phase 4: compose and send Markdown messages

Deliverables:

- Textarea-style composer.
- Send to selected local agent via tracker RPC.
- Send to selected remote agent via tracker RPC using `host/name` or direct registry client, preferring tracker RPC to reuse existing routing/auth.
- Local sent-message store under XDG state/cache, grouped by target agent ID.
- Conversation view merges sent history with inbox messages for the selected agent.

Testing:

- Composer update tests.
- Send command success/error tests with fake clients.
- Sent-history persistence tests.

Review gate: sending text only before attachments.

## Phase 5: message types

Deliverables:

- Add `content_type` to TUI message model and outgoing payload.
- Default `text/markdown`.
- Renderers:
  - `text/markdown` with Glamour
  - `text/plain` escaped/plain
  - `application/vnd.diff` with diff-friendly styling
- Backend should pass through unknown message fields without breaking existing clients if possible.

Testing:

- Renderer tests per content type.
- Backward compatibility test for messages without `content_type`.

Review gate: message-type model reviewed before richer renderers.

## Phase 6: attachments

Deliverables:

- Attach files to outgoing messages.
- Encode attachments as existing backend format:
  - `name`
  - `content_b64`
  - `content_type`
- Attachment list/chips in composer and message view.
- Enforce max attachment/message size before send.
- Optional `gum file` integration for file picker if available; fallback to typed path prompt.

Testing:

- Attachment encoding tests.
- Size-limit tests.
- UI model tests for add/remove attachment.

Review gate: attachments reviewed before popup editor integration.

## Phase 7: tmux popup + Neovim attachment opening

Deliverables:

- Open selected attachment path with:
  - `tmux popup -E 'nvim <path>'`
- Detect tmux availability and current tmux client.
- Safe path handling; never shell-concatenate untrusted paths.
- Fallback: print/open path if not inside tmux.

Testing:

- Command construction tests.
- Fake runner tests for tmux invocation.
- No real tmux required in unit tests.

Review gate: command execution reviewed for safety.

## Phase 8: home-manager-core integration

Deliverables:

- Keep `agent-communicator-tui/flake.nix` as the source of truth for standalone app packaging.
- Expose the communicator through the parent `home-manager-core` flake/package set where appropriate.
- Add a Home Manager module integration so `agent-communicator` is installed with the AI workflow.
- Add a user-facing setup flag under `ai_features`, proposed:
  - `enable_agent_communicator_tui = true;`
- Wire the flag from `flake-template/setup.nix` / user settings into the Home Manager config.
- Because this adds a setup flag, update `docs/Customization.md` with default behavior and true/false behavior.

Testing:

- `nix flake check ./agent-communicator-tui`.
- `nix run ./agent-communicator-tui` smoke test where local platform supports it.
- Parent flake eval test for the default-disabled and enabled Home Manager paths.
- Verify the package is present in `home.packages` when `enable_agent_communicator_tui = true`.

Review gate: parent flake/Home Manager integration reviewed separately.

## Phase 9: tmux smoke validation

Deliverables:

- Launch `agent-communicator` in a new tmux window.
- Validate list, inbox/history loading, send, event refresh, and attachment-opening behavior manually against local tracker.
- Record the smoke-test command and result in the final implementation summary.

Testing:

- Manual tmux-window smoke test requested by review-agent.

## Phase 10: polish

Deliverables:

- Help screen.
- Error/status bar.
- Filtering: local/remote, status, type, cwd substring.
- Sorting: active first, local first, name.
- Configurable registry URL/token behavior through existing tracker environment where possible.

Testing:

- Filter/sort unit tests.
- Golden views for help and error states.

## Open decisions for review

1. Should the communicator register as a first-class local agent so replies can target it explicitly, or should Phase 1 rely on being launched inside an existing agent pane?
2. Should remote sends go through tracker RPC only, or may the TUI call registry HTTP directly?
3. Is Bubble Tea acceptable as the main Go TUI framework, with optional `gum` subprocess helpers?
4. What should the default for `ai_features.enable_agent_communicator_tui` be in templates: enabled with AI workflow, or explicitly opt-in while the TUI is new?
