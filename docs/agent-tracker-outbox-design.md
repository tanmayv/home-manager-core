# Agent Tracker Outbox Design

## Goal

Add a durable per-agent outbox to `agent-tracker` so messages sent by an agent can be tracked alongside inbox messages. The outbox records who sent what, to whom, when, whether delivery was local or remote, and the delivery result.

## Non-goals

- Do not make outbox the source of truth for delivery. Inbox delivery remains authoritative for received messages.
- Do not require every agent to register as a full agent before sending; `cli-user` sends can still be recorded under a CLI identity.
- Do not store raw attachment payloads in outbox. Store attachment metadata only.

## Data model

Outbox records are JSON Lines, matching inbox style.

Path:

```text
$XDG_CACHE_HOME/agent-tracker/outboxes/<sender_id_or_name>.outbox
```

Record shape:

```json
{
  "message_id": "uuid",
  "sender": "coding-agent",
  "sender_id": "agent uuid or null",
  "target": "review-agent",
  "target_agent_id": "uuid or null",
  "target_hostname": "local or remote hostname or null",
  "target_address": "host/name or local/name",
  "route": "local|remote",
  "timestamp": "2026-05-19T11:00:00Z",
  "message": "markdown body",
  "content_type": "text/markdown",
  "attachments": [
    {"name": "file.txt", "content_type": "text/plain", "size": 1234}
  ],
  "delivery_status": "queued|delivered|failed",
  "error": null,
  "read": false
}
```

## Write flow

Outbox should be written inside `handle_send_message`, not by TUI clients.

1. Resolve sender via existing `_identify_agent` logic.
2. Create or reuse `message_id`.
3. Resolve route:
   - local target
   - remote target via `target_address`
4. Append an initial outbox record with `delivery_status: queued`.
5. Attempt delivery:
   - local: call `deliver_local_message`
   - remote: call registry client
6. Append a final status update or rewrite/update the record to `delivered` / `failed`.

Recommended first implementation: append-only status events rather than in-place mutation. This avoids locking complexity and preserves history.

Example append-only records:

```json
{"event":"send_requested", "message_id":"m1", ...}
{"event":"send_delivered", "message_id":"m1", "timestamp":"..."}
```

The read API can fold events into current message state.

## RPC API

Add:

```text
get_outbox
```

Params:

```json
{
  "agent_name": "optional sender name; defaults to caller identity",
  "agent_id": "optional sender id",
  "last_n": 50,
  "target": "optional target filter",
  "clear": false
}
```

Result:

```json
{
  "mode": "history|last_n",
  "messages": [ ... folded outbox records ... ]
}
```

Future optional API:

```text
wait_events
```

Publish `message_sent` events when outbox changes:

```json
{
  "type": "message_sent",
  "sender": "coding-agent",
  "sender_id": "uuid",
  "target": "review-agent",
  "message_id": "uuid",
  "delivery_status": "delivered"
}
```

## Concurrency and safety

- Use a per-outbox file lock or the same global tracker lock pattern used for inbox writes.
- Use append-only JSONL to avoid corrupting files during concurrent sends.
- Never write attachment `content_b64` to outbox.
- Sanitize sender file names by preferring stable UUIDs. Fall back to a safe basename-like normalized sender name for `cli-user`.
- Bound read size with `last_n`; avoid loading unbounded files in TUI paths.

## Remote delivery semantics

For remote sends, `delivered` means accepted by registry (`202`), not necessarily read or locally delivered on remote tracker.

Use statuses:

- `queued`: send started locally
- `accepted`: remote registry accepted message
- `delivered`: local delivery completed, or remote accepted if no stronger ack exists
- `failed`: local/remote send failed synchronously

If future registry acknowledgements are exposed, add:

- `remote_delivered`
- `remote_acked`

## TUI integration

The communicator conversation view should merge:

- selected local agent inbox messages
- current sender outbox messages to that target

Sort by timestamp/message_id and render direction:

- inbound: sender highlighted normally
- outbound: prefix/status like `You → target` and show delivery status

Outbox lets remote conversations show sent history even when remote inbox history is unavailable.

## Test plan

Python tracker tests:

- local send writes outbox record
- remote send writes accepted/delivered outbox record on 202
- failed send writes failed outbox record with error
- attachments record metadata only, not `content_b64`
- `get_outbox` defaults to caller identity
- `get_outbox last_n` bounds results
- concurrent sends do not corrupt JSONL
- renamed target records stable target id/address where available

Go TUI tests:

- conversation merges inbox + outbox
- outbound messages render with target/status
- failed outbound messages are visible

## Suggested implementation phases

1. Add outbox append helper and tests.
2. Record outbox for local sends only.
3. Extend to remote sends.
4. Add `get_outbox` RPC.
5. Publish `message_sent` events.
6. Integrate communicator conversation merge.
