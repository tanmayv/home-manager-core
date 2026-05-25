# Agent Communicator Electron Frontend Implementation Plan

## Goal

Replace the terminal-only `agent-communicator-tui` runtime with a desktop Electron frontend so users can run Agent Communicator as a normal GUI app without keeping a tmux/terminal UI pane open.

The existing terminal TUI should remain available during migration until the Electron app reaches parity.

## Current state

- Terminal UI source: `agent-communicator-tui/`.
- Web prototype/source: `agent-communicator-web/` with REST/SSE bridge endpoints.
- TUI launcher: `modules/scripts/agent-communicator.nix` runs `agent-wrapper .../agent-communicator-tui --no-notify-with-send-keys`.
- Web service module: `modules/agent-communicator-web.nix` runs a local HTTP server on port `8282`.
- Tracker RPC is the source of truth for:
  - agent list,
  - inbox reads,
  - sends,
  - direct pane input,
  - events/read receipts.
- The current `agent-wrapper` only registers an agent when launched inside tmux. A GUI app launched outside tmux will not currently register as `agent-communicator`, so its stable inbox/identity needs first-class headless support.

## Non-goals for the first Electron milestone

- Do not remove the TUI immediately.
- Do not reimplement `agent-tracker` or `agent-registry`.
- Do not expose the local bridge on a public interface.
- Do not require remote registry credentials in renderer/browser code.
- Do not make direct pane input the default send action.

## Proposed architecture

### Components

1. **agent-communicator-core bridge**
   - Local backend process used by Electron.
   - Can evolve from `agent-communicator-web/`.
   - Owns all tracker RPC, outbox persistence, prompt-template loading, saved/hidden-agent state, and event streaming.
   - Listens only on loopback or a Unix socket.
   - Provides a UI-focused API to Electron via HTTP/SSE, WebSocket, or Electron IPC.

2. **Electron main process**
   - Starts/stops the bridge as a child process, or connects to an already-running Home Manager service.
   - Opens the desktop window.
   - Enforces local-only access, port discovery, and optional app single-instance lock.
   - Does not put tracker tokens/secrets into the renderer.

3. **Electron renderer**
   - React/Vite or equivalent frontend.
   - Implements the Agent Communicator UI: agent list, conversation view, composer, prompt picker, saved messages, settings.
   - Talks only to Electron preload APIs or the local bridge.

4. **agent-tracker headless identity support**
   - Required so GUI `agent-communicator` has a stable identity/inbox without a tmux pane.
   - Stable ID remains `00000000-0000-5000-8000-000000000001`.

## Backend/API plan

Extend or replace `agent-communicator-web` with a structured bridge API:

- `GET /api/health`
- `GET /api/agents?include_remote=true`
- `GET /api/conversation?target=<target>&mode=simple|advanced&limit=<n>`
- `GET /api/inbox?agent=agent-communicator&clear=true&last_n=<n>`
- `GET /api/outbox?target=<target>&limit=<n>`
- `POST /api/send-message`
  - Body: `{ target, body, attachments?, prompt_suffix? }`
  - Keeps current inbox behavior and markdown reply suffix.
- `POST /api/send-text`
  - Body: `{ target, text, submit }`
  - Calls tracker `send_input` with `input_type=text`.
- `POST /api/send-key`
  - Body: `{ target, keys }`
  - Calls tracker `send_input` with `input_type=keys`.
- `GET /api/events`
  - SSE or WebSocket stream sourced from tracker `wait_events`.
- `GET /api/prompts`, `GET /api/prompts/:name`, optional `POST/PUT/DELETE` later.
- `GET/POST /api/hidden-agents`
- `GET/POST /api/saved-messages`
- `POST /api/open-pane`
  - Optional: focus/switch to selected local agent pane, replacing TUI `Ctrl-Enter` behavior.

Important behavior to preserve:

- Normal send defaults to inbox `send_message`.
- Direct `/text`/`send-text` and `/key`/`send-key` bypass inbox.
- Outbox records are durable and use message IDs so delivered/notified/read events can update status.
- The displayed/saved outgoing body excludes the hidden markdown reply suffix.
- Direct input text must not be logged in full by bridge or tracker.
- Remote target addressing must preserve `host/agent` and `registry:host/agent` forms.

## Headless communicator identity plan

Add one of the following before making Electron primary:

### Preferred: tracker supports headless agents

- Add tracker RPC support for registering an agent without `session`, `tmux_pane`, and `tmux_socket` when `headless=true`.
- Required fields:
  - `name`, `agent_id`, `wrapper_pid` or `pid`, `agent_type`, `agent_cmd`, `cwd`, `headless=true`.
- State should mark `scope=local`, `agent_type=agent-communicator-electron`, `headless=true`.
- Headless agents should be omitted from pane-input targeting or return a clear error for `send_input`.
- `get_inbox`, `send_message`, `wait_events`, read receipts, registry presence, and heartbeat should work.
- Monitor cleanup should use process liveness/heartbeat rather than tmux pane liveness for headless agents.

### Alternative: bridge owns identity without tracker registration

- Bridge reads `agent-communicator` inbox directly via `get_inbox` using stable `agent_id`/name conventions.
- Simpler initially but weaker: other agents may not see `agent-communicator` as an online target.
- Not recommended for final replacement.

## UI plan

Electron should start with feature parity rather than visual novelty.

### Initial screens

- Agent list sidebar:
  - local/remote badge,
  - status,
  - hidden/de-prioritized section,
  - search/filter.
- Conversation panel:
  - selected 1:1 conversation,
  - Advanced aggregate mode,
  - incoming/outgoing styling,
  - status indicators: queued/sent/delivered/notified/read/failed.
- Composer:
  - default Enter: `send-message` inbox behavior,
  - explicit action selector: Message / Direct Text / Direct Keys,
  - compatibility command parsing for `/msg`, `/text`, `/text --no-submit`, `/key`,
  - multiline editor with keyboard shortcuts.
- Prompt templates:
  - list templates from config directory,
  - edit before send in-app or open external editor later.
- Saved messages:
  - save/unsave selected message,
  - saved-message browser.

### Safety UX

- Direct text/key actions should be visually distinct from normal messages.
- First use of remote direct pane input should show a warning/confirmation preference.
- On failed direct input, keep the composer in direct mode; never silently retry as inbox message.
- Do not append direct input to outbox/message history unless we add a separate redacted audit lane.

## Nix/Home Manager plan

1. Add package(s):
   - `agent-communicator-bridge` or upgraded `agent-communicator-web`.
   - `agent-communicator-electron`.
2. Add module options:
   - `programs.agent-communicator.frontend = "tui" | "electron" | "web";`
   - `programs.agent-communicator.enableTuiFallback = true;`
   - `services.agent-communicator-bridge.enable = true;`
   - `services.agent-communicator-bridge.port` or `socket`.
3. Keep existing `agent-communicator` command stable:
   - In Electron mode, `agent-communicator` launches the desktop app.
   - Add `agent-communicator-tui` as explicit fallback.
4. Linux:
   - `.desktop` entry.
   - user systemd service for bridge if not child-managed.
5. macOS:
   - `.app` packaging if practical through Nix, otherwise app launcher script first.
   - launchd agent for bridge if not child-managed.

## Security plan

- Bind bridge to `127.0.0.1` only, or use Unix socket IPC.
- Add a random per-session auth token if HTTP is used; Electron main/preload injects it, renderer never persists it.
- Do not enable CORS wildcard in production bridge.
- Validate all target fields and direct input fields server-side.
- Redact direct text in logs; log only target, input type, text length, key count, and success/failure.
- If registry proxying remains, narrow it to required read-only endpoints or remove it from Electron path.

## Migration phases

### Phase 0 — design spike

Deliverables:
- Decide API transport: HTTP+SSE, WebSocket, or Electron IPC.
- Decide whether to evolve `agent-communicator-web` or create `agent-communicator-bridge`.
- Decide frontend stack: Electron + React + Vite is the default recommendation.
- Write API contract and data models.

Review gate:
- Architecture approved before code changes.

### Phase 1 — headless identity and bridge hardening

Deliverables:
- Add/test headless tracker registration and heartbeat.
- Make bridge register as stable `agent-communicator` outside tmux.
- Remove production wildcard CORS.
- Add `send-text` and `send-key` bridge endpoints.
- Add event stream reconnection semantics.

Tests:
- Tracker Python unit tests for headless register/heartbeat/list/cleanup.
- Bridge tests for send-message/send-text/send-key payloads.
- Verify normal TUI still works.

Review gate:
- Bridge can run without tmux and receive messages as `agent-communicator`.

### Phase 2 — Electron shell and read-only UI

Deliverables:
- Add `agent-communicator-electron/` app skeleton.
- Main process starts/connects to bridge.
- Renderer displays agent list and selected conversation.
- Live updates via SSE/WebSocket/IPC.
- Nix dev shell/build for local development.

Tests:
- Unit tests for API client/state reducers.
- Manual smoke: launch GUI outside tmux, see agents, receive inbox events.

Review gate:
- Read-only Electron app is usable without terminal UI.

### Phase 3 — sending and direct input parity

Deliverables:
- Normal message send with optimistic outbox and status updates.
- Direct Text action with submit/no-submit.
- Direct Keys action with validated key tokens.
- `/msg`, `/text`, `/key` compatibility commands.
- Failure handling preserves mode/body safely.

Tests:
- UI tests for send modes and failure restore.
- Bridge tests that direct input calls `send_input`, not `send_message`.
- End-to-end local smoke against a real tmux agent pane.

Review gate:
- Electron send behavior matches or improves TUI behavior.

### Phase 4 — feature parity and polish

Deliverables:
- Simple/Advanced views.
- Hidden agents.
- Saved messages.
- Prompt templates.
- Open selected local pane.
- Search/filter.
- Keyboard shortcuts comparable to TUI.

Tests:
- Component tests for view modes and persistence.
- Manual regression against current TUI workflows.

Review gate:
- Electron can be daily-driven by current TUI users.

### Phase 5 — packaging and default switch

Deliverables:
- Home Manager option defaults reviewed.
- `agent-communicator` command launches Electron when selected.
- TUI fallback remains installable.
- Docs updated: install, launch, troubleshooting, security model.

Validation:
- Linux build and launch.
- macOS build/launch or documented limitation.
- `agent-tracker` full tests.
- Bridge/Electron tests.

Review gate:
- User explicitly approves switching default frontend away from terminal TUI.

## Open questions

1. Should Electron start the bridge as a child process, or should Home Manager run the bridge as a persistent service?
2. Should the Electron app be a pure local desktop app, or should the web UI remain separately accessible in a browser?
3. Do we want to keep the existing Go bridge and write only Electron frontend code, or move bridge logic into Electron main process?
4. What platforms are required for the first supported build: Linux only, macOS only, or both?
5. Should direct input actions be hidden behind a confirmation/preference for remote agents?
6. Should `agent-communicator-web` be renamed to `agent-communicator-bridge` to reflect its role?

## Suggested first chunk

Implement Phase 0 and the first half of Phase 1:

- Add final API contract doc.
- Add headless registration support in `agent-tracker`.
- Add bridge endpoint tests for `send-message`, `send-text`, and `send-key`.
- Keep existing TUI and web behavior unchanged.

This chunk unblocks the Electron app because it removes the current tmux-pane identity dependency.
