# Agent Communicator Architecture and Requirements

`agent-communicator` is a Bubble Tea terminal UI for messaging agents through `agent-tracker` and `agent-registry`.

## Goals

- Provide a persistent, keyboard-driven messaging UI for local and remote agents.
- Run as a wrapped agent named `agent-communicator`.
- Use a stable agent ID so its inbox persists across restarts:
  `00000000-0000-5000-8000-000000000001`.
- Keep sent-message history durable in a communicator-local outbox JSONL file.
- Support Simple and Advanced views:
  - Simple: selected conversation, displaying the latest 50 messages.
  - Advanced: aggregate inbox from everyone, displaying the latest 200 messages; agent list still chooses the send target.

## Main paths

- TUI source: `agent-communicator-tui/`
- Home Manager wrapper: `modules/scripts/agent-communicator.nix`
- Tracker client: `agent-communicator-tui/internal/tracker/`
- Registry client: `agent-communicator-tui/internal/registry/`
- Persistent outbox: `$XDG_STATE_HOME/agent-communicator/outbox.jsonl`, fallback `~/.local/state/agent-communicator/outbox.jsonl`
- Prompt templates: `$XDG_CONFIG_HOME/agent-communicator/prompts/<prompt-name>.md`, fallback `~/.config/agent-communicator/prompts/<prompt-name>.md`
- Tracker inbox: `~/.cache/agent-tracker/inboxes/<agent-id>.inbox`

## Runtime identity

`modules/scripts/agent-communicator.nix` launches the TUI through `agent-wrapper`:

```sh
export SUGGESTED_AGENT_NAME=agent-communicator
export AGENT_ID=00000000-0000-5000-8000-000000000001
exec agent-wrapper .../agent-communicator-tui --no-notify-with-send-keys "$@"
```

The Go app defaults `ownName` to `AGENT_NAME`, falling back to `agent-communicator` for direct launches.

## Data flow

### Agent list

Agent rows are loaded from `agent-tracker-ctl list` because it includes local plus remote registry agents. Normal refresh uses a bounded timeout; `Ctrl-R` uses a longer timeout. If list refresh fails, the TUI keeps last-good rows/messages, marks the agent list stale, and disables sending until a later list succeeds.

### Inbox

The TUI calls tracker RPC `get_inbox` via `internal/tracker.Client.ReadInbox`.

- Simple View loads the communicator inbox and filters messages for the selected row.
- Advanced View loads the communicator inbox without filtering and merges all outbox records.

Reading inbox marks returned messages read in `agent-tracker`. The tracker publishes `message_read` events for read receipts.

### Sending

Sends go through tracker RPC `send_message` via `SendMessageWithID`.

Important behavior:

- Sender name is always `agent-communicator`.
- A local outbox record is created before delivery.
- The outbox record ID is passed as `message_id` so delivered/read events can update the same record.
- The delivered body has a hidden suffix:
  `(PS: Reply in markdown format.)`
- The persisted/displayed body does **not** include that suffix.
- Sends are optimistic: the message appears immediately. On send failure, the optimistic message is removed and the body is restored to the composer.

### Prompt templates

Prompt templates are Markdown files in `$XDG_CONFIG_HOME/agent-communicator/prompts/` or `~/.config/agent-communicator/prompts/`.

- File names are `<prompt-name>.md`; non-Markdown files are ignored.
- Press `Ctrl-O` to open the prompt selector.
- Selecting a prompt copies it into a temporary Markdown file and opens it in Neovim.
- The temporary buffer is marked modified so `:x` writes/sends even if the template text is unchanged.
- The edited prompt is sent only if the temporary file was written/saved by the editor. Exiting with `:q!` cancels the send.
- Home Manager installs a sample `test.md` prompt for smoke testing.

### Outbox

`outbox.go` owns durable sent history.

- `appendOutbox` appends JSONL records.
- `loadOutbox` de-dupes duplicate record IDs, keeping the latest record.
- `writeOutbox` rewrites records when delivery/read status changes.
- `outboxMessage` converts records into display messages.

Read status:

- `Delivered`, `Notified`, `Read` map to display markers.
- Status events update both in-memory state and persisted outbox.

## Views

### Simple View

- Left panel: `Agents` list.
- Right panel: `Conversation` for selected agent.
- `Ctrl-N` / `Ctrl-P` changes selected agent within the focused active/hidden section and keeps it visible in the agent-list viewport.
- `Ctrl-H` toggles the selected agent's hidden/de-prioritized state. Hidden agents remain sendable.
- `Shift-Tab` toggles agent-list focus between active and hidden sections.

### Advanced View

- Same `Agents` and `Conversation` panels.
- Conversation shows aggregate messages from everyone.
- Agent list determines the send target, same as Simple View. Use `Ctrl-N` / `Ctrl-P` to change it within the focused active/hidden section.
- Selecting messages only changes the focused/opened message; it does not change the send target.
- The composer does not show the receiver name; the selected agent card is the send-target indicator.

## Message limits and performance

Display limits are applied before Markdown rendering, highlighting, wrapping, and box rendering:

- Simple View renders only the latest 50 messages for the selected 1:1 conversation.
- Advanced View renders only the latest 200 aggregate messages.
- Simple inbox refresh fetches 100 recent inbox entries before filtering, so mixed-agent inboxes still have room to find selected-agent messages.
- Advanced inbox refresh fetches 200 recent inbox entries.
- The outbox remains durable; display limiting must not delete history from `outbox.jsonl`.
- On startup, communicator prunes its own inbox and outbox JSONL files to the latest 1000 records each to cap disk growth and startup parse cost.

## Layout

Important files:

- `view.go`: panels, composer, message viewport, agent cards.
- `bubbles.go`: message box rendering and direction styling.
- `agent_scroll.go`: agent-list viewport/scrolling.
- `selection_scroll.go`: selected message auto-scroll.

Constraints:

- Do not rely on Lip Gloss `Height` to clip overflowing content. It pads short content but does not safely truncate long content.
- Explicitly compute available message height and render at most that many lines.
- Keep panel widths and message box widths conservative to avoid terminal wrapping.
- Message boxes currently use full boxes with direction-specific side borders:
  - outgoing: double left border `║`
  - incoming: double right border `║`

## Keyboard behavior

- `Ctrl-Q`: quit
- `Ctrl-R`: refresh agent list with longer timeout and reload outbox
- `Ctrl-T`: toggle Simple/Advanced view
- `Ctrl-N` / `Ctrl-P`: select next/previous agent within the focused active/hidden section
- `Ctrl-O`: open prompt-template selector; selected prompts are edited in a temporary file and sent only when saved
- `Ctrl-H`: toggle selected agent hidden/de-prioritized
- `Tab` / `Shift-Tab`: toggle agent-list focus between active and hidden sections
- `Up` / `Down`: select message and auto-scroll it into view
- `Ctrl-U` / `Ctrl-D`: scroll message viewport
- `Ctrl-E`: open selected message in editor
- `Ctrl-Enter`: focus/switch to the currently selected agent's tmux pane when the selected agent is local
- `Ctrl-F`: save/unsave selected message
- `Enter`: send composer text
- Plain typing goes to composer
- `Ctrl-W`: delete previous word

No mouse support/capture.

## Markdown rendering

`markdown.go` implements lightweight Markdown rendering:

- headings
- bullets
- pipe tables
- fenced code blocks
- links
- basic syntax highlighting for Go/Python/Nix/Shell

Timestamps are rendered in GMT+5:30 as human-readable strings, without timezone suffix, e.g. `20 May 2026 15:54`.

## Tracker/registry assumptions

- `agent-tracker` owns actual inbox files and read events.
- Inbox file access must be locked/atomic in tracker to avoid read/rewrite races.
- Remote messages arrive through registry and are delivered into local tracker inboxes.
- Remote status/read receipts are relayed as tracker events.

## Important tests

Run before switching/committing:

```sh
cd agent-communicator-tui
go test ./...
nix flake check

cd ../modules/agent-tracker
python3 -m unittest discover
```

Common test areas:

- `*_view_test.go`: layout/view rendering
- `bubbles_test.go`: message box behavior/colors
- `agent_scroll_test.go`: agent list scrolling/clipping
- `selection_scroll_test.go`: message selection auto-scroll
- `outbox_test.go`, `read_status_test.go`: durable outbox/read receipts
- `advanced_target_test.go`: advanced message selection does not update send target

## Home Manager deployment

Use local override for testing uncommitted changes:

```sh
home-manager switch --flake ~/.config/home-manager#core --override-input minimal-cloudtop /Users/tanmayvijay/home-manager-core
```

After switching, restart/reopen existing `agent-communicator` instances to pick up the new binary.

Known recurring warning on macOS may appear for `agent-tracker` launchd restart; if tracker changes are involved, manually restart with `launchctl bootout/bootstrap/kickstart` if needed.

## Development guidance

- Keep files under roughly 300 LOC.
- Add or update tests for behavior changes.
- Prefer small, explicit layout calculations over relying on terminal wrapping.
- Preserve UI state on transient tracker/list failures.
- Avoid clearing inboxes unless explicitly requested.
- Do not lose or duplicate outbox records; use message IDs for de-dupe.
