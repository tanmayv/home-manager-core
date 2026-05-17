# agent-registry — Design Document

## Overview & Goals

`agent-registry` is a central HTTP service that runs at `agent-registry.mundus.in` and
provides network-wide visibility and cross-machine message delivery for the AI agent
ecosystem managed by `agent-tracker` daemons.

### Goals

1. Every machine running `agent-tracker` registers itself with the registry so its agents
   become discoverable from any other machine on the network or VPN.
2. An agent on machine-1 can send a message to an agent on machine-2 using a single,
   uniform address — the registry resolves the target and relays the message.
3. Heartbeat liveness tracking mirrors the existing local model: stale trackers and their
   agents are marked and eventually evicted.
4. Backward compatibility: local-only `send_message` continues to work exactly as today.
   Only messages with a remote-qualified address use the registry path.
5. The system tolerates the target tracker being temporarily offline and returns a clear
   error rather than silently dropping messages.

### Non-Goals

- The registry does not store agent inbox content. Inboxes remain local to each tracker.
- The registry does not replace or replicate `agent-tracker` state; it caches just enough
  to route messages and answer network-wide queries.
- The registry does not orchestrate or spawn agents.

---

## Architecture Diagram

```
                         ┌──────────────────────────────────────────┐
                         │         agent-registry.mundus.in          │
                         │                                            │
                         │  ┌──────────┐   ┌────────────────────┐   │
                         │  │  Tracker │   │    Agent Cache     │   │
                         │  │  Store   │   │  (name → tracker)  │   │
                         │  └──────────┘   └────────────────────┘   │
                         │        HTTP :8080  (TLS optional)         │
                         └─────────┬───────────────┬────────────────┘
                                   │               │
           ┌───────────────────────┘               └──────────────────────────┐
           │                                                                   │
  192.168.0.x / 10.27.0.x                                        10.27.0.x / VPN peer
           │                                                                   │
  ┌────────▼──────────────────┐                           ┌────────────────────▼──────┐
  │  machine-1  (e.g. mac)    │                           │  machine-2  (e.g. linux)  │
  │                           │                           │                           │
  │  agent-tracker  (unix)    │                           │  agent-tracker  (unix)    │
  │  + HTTP sidecar :19876    │                           │  + HTTP sidecar :19876    │
  │                           │                           │                           │
  │  Agents: claude-1, foo    │                           │  Agents: gemini-1, bar    │
  └───────────────────────────┘                           └───────────────────────────┘
```

Message flow overview (cross-machine):
```
  claude-1 (machine-1)
      │  1. RPC send_message(target="machine-2/gemini-1", ...)
      ▼
  agent-tracker (machine-1)
      │  2. POST /messages  →  registry
      ▼
  agent-registry
      │  3. Looks up tracker record for machine-2
      │  4. POST /deliver  →  machine-2:19876
      ▼
  agent-tracker HTTP sidecar (machine-2)
      │  5. Writes to gemini-1's local inbox file
      │  6. tmux send-keys notification
      ▼
  gemini-1 (machine-2)
```

---

## Data Models

### TrackerRecord

Stored in the registry's in-memory store (persisted to a flat JSON file on disk for
restart recovery).

```json
{
  "tracker_id":      "string (UUID, assigned by registry at first registration)",
  "hostname":        "string (e.g. 'kamsharm-mac')",
  "address":         "string (IP or hostname reachable from registry, e.g. '192.168.0.42')",
  "http_port":       "integer (port of the tracker's HTTP sidecar, default 19876)",
  "token_hash":      "string (SHA-256 hex of the pre-shared token; stored, never returned in API)",
  "registered_at":   "string (ISO-8601 UTC)",
  "last_heartbeat":  "string (ISO-8601 UTC) | null",
  "status":          "string: 'active' | 'stale' | 'gone'"
}
```

Field semantics:
- `tracker_id`: stable UUID. Survives tracker daemon restarts as long as the tracker
  re-registers with the same `hostname`. On conflict (same hostname, different
  `tracker_id`), the new registration wins and updates the existing record.
- `address`: the IP the tracker reports during registration. The registry uses this to
  forward messages. Trackers behind the VPN report their VPN tunnel IP.
- `status` transitions:
  - `active`: heartbeat received within `TRACKER_STALE_SECONDS` (default 60 s).
  - `stale`: no heartbeat for 60–180 s; agents are still cached but message delivery
    returns `503` with `"tracker_status": "stale"`.
  - `gone`: no heartbeat for >180 s; record is tombstoned and agents are removed from
    the agent cache. The tracker_id is retained as a tombstone for 24 h so stale
    clients get a meaningful error.

### AgentRecord

Cached at the registry. Authoritative state lives in the local tracker.

```json
{
  "agent_id":    "string (UUID — same stable UUID the local tracker uses)",
  "name":        "string (current display name)",
  "aliases":     ["string"],
  "tracker_id":  "string (foreign key → TrackerRecord.tracker_id)",
  "hostname":    "string (denormalized for fast lookup)",
  "status":      "string: 'idle' | 'working' | 'waiting' | 'spawning' | 'unknown'",
  "agent_type":  "string",
  "agent_cmd":   "string",
  "last_seen":   "string (ISO-8601 UTC — set when the tracker last pushed this agent)"
}
```

Design decision: the registry stores **full agent status** because it enables useful
network-wide queries (`GET /agents?status=idle`). The tracker is the authority; the
registry holds a cache that can be up to one heartbeat interval stale.

Agent records are replaced wholesale on every tracker heartbeat (the heartbeat carries a
full agent list). There is no partial-update path for individual agent fields at the
registry level — that complexity stays local to the tracker.

---

## REST API

All requests and responses use `Content-Type: application/json`.
All timestamps are ISO-8601 UTC strings (`2026-05-17T14:22:01.123456Z`).
The registry listens on `http://agent-registry.mundus.in:8080` (TLS via a reverse proxy
is recommended but out of scope for this document).

Authentication is covered in the Security section. All protected endpoints require the
header `Authorization: Bearer <token>`.

### Error Envelope

Every error response has this shape:

```json
{
  "error":   "string (machine-readable code, e.g. 'tracker_not_found')",
  "message": "string (human-readable description)"
}
```

---

### 1. Tracker Registration

**`POST /trackers`**

Called by a tracker daemon when it starts up or reconnects after a network partition.
This is an upsert: if a tracker with the same `hostname` already exists, its record is
refreshed (including a new `tracker_id` if the caller provides a different one; the
caller's `tracker_id` always wins).

Request body:
```json
{
  "tracker_id":  "string (UUID generated by the tracker at first install; persisted locally)",
  "hostname":    "string",
  "address":     "string (IP reachable from registry)",
  "http_port":   "integer",
  "agents":      [ "<AgentRecord>", "..." ]
}
```

The `agents` array is the full current agent list on that tracker. The registry replaces
its cached agent set for this tracker with the provided list.

Response `201 Created` (new tracker) or `200 OK` (existing tracker refreshed):
```json
{
  "tracker_id":    "string",
  "registered_at": "string"
}
```

Error responses:
- `400 Bad Request` — missing required fields.
  `{"error": "invalid_request", "message": "tracker_id, hostname, address, http_port are required"}`
- `401 Unauthorized` — missing or invalid auth token.
  `{"error": "unauthorized", "message": "invalid or missing token"}`

---

### 2. Tracker Heartbeat

**`POST /trackers/{tracker_id}/heartbeat`**

Called every 30 s by the tracker daemon. Carries the current agent list so the registry
stays in sync without a separate agent-sync endpoint.

Path parameters:
- `tracker_id`: string UUID

Request body:
```json
{
  "agents": [ "<AgentRecord>", "..." ]
}
```

The `agents` array replaces the registry's cached agent list for this tracker. Pass an
empty array `[]` if no agents are currently running.

Response `200 OK`:
```json
{
  "ok": true,
  "server_time": "string (ISO-8601 UTC)"
}
```

Error responses:
- `401 Unauthorized` — bad token.
- `404 Not Found` — `tracker_id` unknown.
  `{"error": "tracker_not_found", "message": "tracker not registered; call POST /trackers first"}`
  The tracker must re-register on receiving this response.
- `400 Bad Request` — malformed body.

---

### 3. Agent Status Push

**`POST /trackers/{tracker_id}/agent-update`**

Called by the tracker whenever a single agent transitions status (e.g. `idle→working`,
`working→idle`, `spawning→idle`). Updates only that agent's cached record in the registry.
Does not replace the full agent list — the heartbeat remains the authoritative full-sync.

This keeps `GET /agents?status=idle` near-realtime without requiring a shorter heartbeat
interval.

Path parameters:
- `tracker_id`: string UUID

Request body:
```json
{
  "agent_id": "string (UUID of the agent whose status changed)",
  "status":   "string: 'idle' | 'working' | 'waiting' | 'spawning' | 'unknown'"
}
```

Processing:
1. Look up the agent in the registry's cache by `agent_id`.
2. If not found (agent not yet pushed via heartbeat), return `404` — the tracker should
   wait for the next heartbeat to sync this agent rather than retrying the push.
3. Verify the agent belongs to `tracker_id`. If not, return `403`.
4. Update only the `status` and `last_seen` fields of the cached agent record.

Response `200 OK`:
```json
{"ok": true}
```

Error responses:
- `400 Bad Request` — `{"error": "invalid_request", "message": "agent_id and status are required"}`.
- `401 Unauthorized`.
- `403 Forbidden` — `{"error": "wrong_tracker", "message": "agent does not belong to this tracker"}`.
- `404 Not Found` — `{"error": "agent_not_found", "message": "agent not in registry cache; wait for next heartbeat"}`.

**Tracker-side trigger:** the existing `handle_update_agent` in `rpc_handler.py` already
receives all agent status transitions. Add a non-blocking call to the registry HTTP client
there, fire-and-forget (log failures, never raise).

---

### 4. Tracker Deregistration

**`DELETE /trackers/{tracker_id}`**

Called by the tracker on clean shutdown. Marks the tracker `gone` immediately and removes
its agents from the registry cache.

Path parameters:
- `tracker_id`: string UUID

Response `200 OK`:
```json
{"ok": true}
```

Error responses:
- `401 Unauthorized`.
- `404 Not Found` — `{"error": "tracker_not_found", "message": "no such tracker"}`.

---

### 4. List Trackers

**`GET /trackers`**

Returns all known trackers and their cached agent lists.

Query parameters (all optional):
- `status` — filter by tracker status: `active | stale | gone`. Default: returns all.

Response `200 OK`:
```json
{
  "trackers": [
    {
      "tracker_id":     "string",
      "hostname":       "string",
      "address":        "string",
      "http_port":      "integer",
      "registered_at":  "string",
      "last_heartbeat": "string | null",
      "status":         "string",
      "agents": [
        {
          "agent_id":   "string",
          "name":       "string",
          "aliases":    ["string"],
          "status":     "string",
          "agent_type": "string",
          "agent_cmd":  "string",
          "last_seen":  "string"
        }
      ]
    }
  ]
}
```

Note: `token_hash` is never included in any response.

Error responses:
- `401 Unauthorized`.

---

### 5. List Agents (Network-Wide)

**`GET /agents`**

Returns all cached agents across all trackers.

Query parameters (all optional):
- `name` — exact display name match (case-sensitive).
- `name_prefix` — prefix match on display name.
- `status` — filter by agent status.
- `tracker_id` — filter to agents on a specific tracker.
- `hostname` — filter by tracker hostname.

Response `200 OK`:
```json
{
  "agents": [
    {
      "agent_id":   "string",
      "name":       "string",
      "aliases":    ["string"],
      "tracker_id": "string",
      "hostname":   "string",
      "status":     "string",
      "agent_type": "string",
      "agent_cmd":  "string",
      "last_seen":  "string"
    }
  ]
}
```

Error responses:
- `401 Unauthorized`.

---

### 6. Get Agent by ID

**`GET /agents/{agent_id}`**

Returns a single agent by its stable UUID.

Response `200 OK`:
```json
{
  "agent_id":   "string",
  "name":       "string",
  "aliases":    ["string"],
  "tracker_id": "string",
  "hostname":   "string",
  "address":    "string",
  "http_port":  "integer",
  "status":     "string",
  "agent_type": "string",
  "agent_cmd":  "string",
  "last_seen":  "string"
}
```

Error responses:
- `401 Unauthorized`.
- `404 Not Found` — `{"error": "agent_not_found", "message": "no agent with that ID is registered"}`.

---

### 7. Send Cross-Tracker Message

**`POST /messages`**

The source tracker calls this endpoint when it resolves that the target agent is on a
different tracker. The registry performs the delivery to the target tracker's HTTP sidecar.

Request body:
```json
{
  "sender_agent_id":   "string (UUID of the sending agent)",
  "sender_agent_name": "string (display name at time of send)",
  "sender_tracker_id": "string (UUID of the sending tracker)",
  "target_agent_id":   "string (UUID of the target agent; preferred)",
  "target_agent_name": "string (display name; used only if target_agent_id is absent)",
  "message":           "string"
}
```

At least one of `target_agent_id` or `target_agent_name` must be provided.
`target_agent_id` takes priority. `target_agent_name` **must** be accompanied by
`target_hostname` to avoid ambiguity — bare name resolution is not supported at the
registry level.

Request body (updated to include `target_hostname` and optional attachments):
```json
{
  "sender_agent_id":   "string",
  "sender_agent_name": "string",
  "sender_tracker_id": "string",
  "target_agent_id":   "string (preferred)",
  "target_agent_name": "string (requires target_hostname when used)",
  "target_hostname":   "string (required when target_agent_name is used)",
  "message":           "string | null",
  "attachments": [
    {
      "name":         "string",
      "content_type": "string",
      "content_b64":  "string (base64 payload)"
    }
  ]
}
```

At least one of `message` or `attachments` must be present.
For this slice, attachments are carried inline as base64 in JSON. This avoids introducing
multipart parsing complexity while still supporting cross-tracker file transfer.
Large payloads are accepted up to an implementation-defined request-body limit; larger
requests return `413 payload_too_large`.

Resolution logic (registry-side):
1. If `target_agent_id` is provided, look it up in the agent cache. If found, proceed.
2. If only `target_agent_name` is provided and `target_hostname` is absent, return `400`
   with `"error": "hostname_required"` — bare-name global resolution is not supported.
3. If `target_agent_name` + `target_hostname` are provided, filter the agent cache to
   agents on that tracker hostname and match on `name` or `aliases`. If no match, `404`.
4. If the resolved agent's tracker is the same as `sender_tracker_id`, return `400` with
   `"error": "same_tracker"` — local send must be used instead.
5. Check that the target tracker's `status` is `active`. If `stale` or `gone`, return `503`.
6. Forward the message to the target tracker via `POST /deliver` on its HTTP sidecar.

Response `202 Accepted` (delivery accepted by target tracker):
```json
{
  "ok":             true,
  "target_agent_id": "string",
  "target_name":    "string",
  "target_tracker": "string (hostname)"
}
```

Error responses:
- `400 Bad Request`:
  - `{"error": "invalid_request", "message": "message text is required"}`
  - `{"error": "same_tracker", "message": "target agent is on the same tracker; use local send"}`
  - `{"error": "missing_target", "message": "provide target_agent_id or target_agent_name"}`
  - `{"error": "hostname_required", "message": "target_hostname is required when using target_agent_name; bare-name global resolution is not supported"}`
- `401 Unauthorized`.
- `404 Not Found` — `{"error": "agent_not_found", "message": "no agent with that ID or name is registered on the specified tracker"}`.
- `503 Service Unavailable`:
  - `{"error": "tracker_offline", "message": "target tracker is stale or gone", "tracker_status": "stale|gone"}`
  - `{"error": "delivery_failed", "message": "target tracker returned an error: <detail>"}`
  - `{"error": "tracker_unreachable", "message": "could not connect to target tracker: connection refused"}`

The registry does **not** queue messages. If the target tracker is offline, the caller
receives `503` immediately and is responsible for retry logic. Rationale: queuing adds
significant state management risk; the inbox model already handles "deliver when ready"
at the local level once the message reaches the tracker.

---

### 8. Registry Health

**`GET /healthz`**

No authentication required. Returns `200 OK` with `{"ok": true}` when the registry is
running. Used by load balancers and monitoring.

---

## Heartbeat & Liveness

### Intervals and Thresholds

| Parameter                  | Default | Notes                                    |
|----------------------------|---------|------------------------------------------|
| Tracker heartbeat interval | 30 s    | Configurable via `AGENT_TRACKER_HB_INTERVAL` env var |
| `TRACKER_STALE_SECONDS`    | 60 s    | No heartbeat for this long → `stale`     |
| `TRACKER_GONE_SECONDS`     | 180 s   | No heartbeat for this long → `gone`      |
| Tombstone retention        | 24 h    | `gone` records kept before purge         |
| Registry monitor interval  | 15 s    | Background sweep frequency               |

### State Transitions

```
  active ──(no heartbeat > 60 s)──► stale ──(no heartbeat > 180 s)──► gone
  stale  ──(heartbeat received)───► active
  gone   ──(new registration)─────► active  (record resurrected)
  gone   ──(after 24 h)───────────► purged from memory and disk
```

### What Happens at Each Transition

**active → stale:**
- Registry logs: `tracker {tracker_id} ({hostname}) is stale; last heartbeat {delta}s ago`.
- Agents on this tracker are NOT removed from the cache; they remain visible with their
  last-known status.
- New `POST /messages` targeting these agents returns `503` with `"tracker_status": "stale"`.
- `GET /agents` and `GET /trackers` still return the agents; the tracker record shows
  `"status": "stale"`.

**stale → gone:**
- Registry logs: `tracker {tracker_id} ({hostname}) marked gone`.
- All agents cached for this tracker are removed from the agent cache.
- Tracker record is retained as a tombstone with `"status": "gone"` for 24 h.
- `GET /agents/{agent_id}` for any of the removed agents returns `404`.

**gone → active (re-registration):**
- Tracker calls `POST /trackers` again (same `tracker_id` or same `hostname`).
- The registry replaces the tombstone with a fresh active record.
- The agent list from the registration payload repopulates the cache.
- No special handling required on the tracker side; `POST /trackers` is always an upsert.

### Tracker Reconnect Behaviour

1. On startup, the tracker daemon calls `POST /trackers` with its full agent list.
2. If the registry responds `200/201`, the tracker is registered and begins heartbeats
   every 30 s.
3. If `POST /trackers` returns a network error, the tracker retries with exponential
   backoff: 5 s → 10 s → 20 s → 40 s → 60 s, then every 60 s until success.
4. If `POST /trackers/{tracker_id}/heartbeat` returns `404`, the tracker immediately calls
   `POST /trackers` to re-register (the registry may have restarted and lost state).
5. During any interval where the tracker cannot reach the registry, local operation
   continues normally — agents can still be tracked and messaged locally.

---

## Cross-Tracker Message Flow

### Addressing

The canonical network-wide address for an agent is:

```
<tracker_hostname>/<agent_name_or_uuid>
```

Examples: `kamsharm-mac/claude-1`, `workstation/a3f5c2d1-...`.

**Bare names (no `/`) are always local-only.** The registry never performs bare-name
global resolution. A `target_address` without a hostname prefix is treated identically to
omitting `target_address` — it resolves against the local tracker only. This eliminates
all name-ambiguity errors at the registry level; two trackers may have agents with the
same display name without conflict.

The string `"local"` is a reserved hostname that explicitly forces local-only delivery,
useful for testing or scripting where the address is constructed programmatically.

### Extended `send_message` RPC

The existing `send_message` JSON-RPC params gain one optional field:

```json
{
  "target_address": "string | null"
}
```

All existing fields (`agent_id`, `agent_name`, `sender_name`, `sender_id`, `message`)
remain unchanged. Resolution rules when `target_address` is present:

1. `target_address` is absent, null, or contains no `/` → **local delivery only**
   (existing logic, untouched). Bare names never trigger registry lookup.
2. `target_address` contains `/` → split on first `/` into `hostname` and `name_or_id`.
   - If hostname == local machine hostname or `"local"` → local delivery.
   - Otherwise → call `GET /agents/{uuid}` (if `name_or_id` is a UUID) or
     `GET /agents?name=<name_or_id>&hostname=<hostname>` on the registry to resolve the
     `agent_id`, then `POST /messages`.

### Full Sequence Diagram

```
Agent A (machine-1)      tracker-1 (machine-1)    agent-registry      tracker-2 sidecar (machine-2)   Agent B (machine-2)
      │                          │                      │                          │                          │
      │  RPC send_message(       │                      │                          │                          │
      │   target_address=        │                      │                          │                          │
      │   "machine-2/gemini-1",  │                      │                          │                          │
      │   message="hello")       │                      │                          │                          │
      │─────────────────────────►│                      │                          │                          │
      │                          │                      │                          │                          │
      │                          │  GET /agents         │                          │                          │
      │                          │   ?name=gemini-1     │                          │                          │
      │                          │─────────────────────►│                          │                          │
      │                          │                      │                          │                          │
      │                          │  200 [{agent_id: X,  │                          │                          │
      │                          │   tracker_id: T2}]   │                          │                          │
      │                          │◄─────────────────────│                          │                          │
      │                          │                      │                          │                          │
      │                          │  POST /messages      │                          │                          │
      │                          │  {sender_agent_id:A, │                          │                          │
      │                          │   target_agent_id:X, │                          │                          │
      │                          │   message:"hello"}   │                          │                          │
      │                          │─────────────────────►│                          │                          │
      │                          │                      │  [resolve T2:            │                          │
      │                          │                      │   address=10.27.0.8,     │                          │
      │                          │                      │   port=19876,            │                          │
      │                          │                      │   status=active]         │                          │
      │                          │                      │                          │                          │
      │                          │                      │  POST /deliver           │                          │
      │                          │                      │  {target_agent_id: X,    │                          │
      │                          │                      │   sender_name:"claude-1",│                          │
      │                          │                      │   sender_tracker:        │                          │
      │                          │                      │    "machine-1",          │                          │
      │                          │                      │   message:"hello"}       │                          │
      │                          │                      │─────────────────────────►│                          │
      │                          │                      │                          │  write inbox file        │
      │                          │                      │                          │  tmux send-keys          │
      │                          │                      │                          │─────────────────────────►│
      │                          │                      │  200 {"ok": true}        │                          │
      │                          │                      │◄─────────────────────────│                          │
      │                          │  202 {"ok": true}    │                          │                          │
      │                          │◄─────────────────────│                          │                          │
      │  JSON-RPC result: true   │                      │                          │                          │
      │◄─────────────────────────│                      │                          │                          │
```

**Target tracker offline path:**

```
  [at POST /messages — registry checks tracker T2 status]

  T2 status = "stale" or "gone"
  └─► registry returns 503:
      {"error": "tracker_offline", "tracker_status": "stale", "message": "..."}

  tracker-1 returns JSON-RPC error to Agent A:
  {"code": -32603, "message": "Remote delivery failed: target tracker is stale (machine-2)"}
```

---

## Tracker-Side HTTP Server

Each `agent-tracker` daemon gains a minimal HTTP sidecar thread bound to `0.0.0.0:19876`
(configurable via `AGENT_TRACKER_HTTP_PORT`). The sidecar is started from the existing
`main()` in `agent-tracker.py` alongside the Unix socket server.

The sidecar exposes exactly two endpoints.

### POST /deliver

Called exclusively by the registry to deliver a forwarded message to a local agent.

Authentication: `Authorization: Bearer <token>` — the same pre-shared token this tracker
used to register. The sidecar rejects any request whose token does not match.

Request body:
```json
{
  "target_agent_id":  "string",
  "sender_name":      "string",
  "sender_agent_id":  "string",
  "sender_tracker":   "string (hostname of the originating tracker)",
  "message":          "string | null",
  "attachments": [
    {
      "name":         "string",
      "content_type": "string",
      "content_b64":  "string (base64 payload)"
    }
  ],
  "sent_at":          "string (ISO-8601 UTC)"
}
```

At least one of `message` or `attachments` must be present.

Processing:
1. Look up `target_agent_id` in local tracker state via `state.get_agent_name_by_id()`.
2. If not found: `404 {"error": "agent_not_found", "message": "no local agent with that ID"}`.
3. Construct a message object:
   ```json
   {
     "sender":    "<sender_name> (via <sender_tracker>)",
     "timestamp": "<sent_at>",
     "message":   "<message>",
     "read":      false
   }
   ```
4. Append to the agent's inbox file (same path as `handle_send_message` uses today).
   If attachments are present, write them to per-message files under the local inbox
   storage area and store attachment metadata/path references in the inbox entry.
5. If the agent is busy (`working`, `waiting`, `spawning`), queue the notification via
   the existing `pending_notifications` mechanism.
6. Otherwise, call `tmux_util.send_keys()` with the notification string.

Response `200 OK`:
```json
{"ok": true}
```

Error responses:
- `400` — `{"error": "invalid_request", "message": "target_agent_id and message or attachments are required"}`.
- `413` — `{"error": "payload_too_large", "message": "request body exceeds limit"}`.
- `401` — `{"error": "unauthorized", "message": "invalid or missing token"}`.
- `404` — agent not found (see above).
- `500` — `{"error": "inbox_error", "message": "failed to write to inbox: <os error>"}`.

### GET /agents

Called by the registry to resync agent state (e.g. after a long stale period). Also
useful for debugging from the command line.

Authentication: same pre-shared token.

Response `200 OK`:
```json
{
  "agents": [
    {
      "agent_id":   "string",
      "name":       "string",
      "aliases":    ["string"],
      "status":     "string",
      "agent_type": "string",
      "agent_cmd":  "string"
    }
  ]
}
```

Note: `tmux_pane`, `tmux_socket`, `session`, and PID fields are intentionally omitted —
they have no meaning outside the local machine.

---

## Agent Addressing Spec

### Canonical Format

```
<hostname>/<agent_name_or_uuid>
```

- `<hostname>` — the tracker's registered `hostname` (logical name, not necessarily DNS).
- `<agent_name_or_uuid>` — the agent's current display name or its stable UUID.

The string `"local"` is a reserved hostname that forces local-only delivery, equivalent
to omitting `target_address` entirely.

**Bare names and bare UUIDs (no `/`) are always local-only.** The registry never resolves
addresses without a hostname prefix. This rule eliminates all ambiguity: two trackers may
have agents with the same display name without any conflict or coordination.

### `agent-tracker-ctl` CLI Extension

```
agent-tracker-ctl send-message <target> "<message>"
```

Where `<target>` is:
- A local agent name or UUID (existing behaviour, unchanged — local delivery only).
- `<hostname>/<name_or_uuid>` (new; triggers registry path).

---

## Security Model

### Threat Model

The registry is reachable from `192.168.0.0/24`, `10.27.0.0/24`, and over VPN. All
traffic travels over trusted physical or VPN links, but we still prevent rogue processes
from forging agent identities or flooding inboxes.

### Pre-Shared Token Authentication

A single 256-bit random token (base64url-encoded) is shared across all trackers and the
registry. The same token is used in both directions:

- Tracker → registry (`POST /trackers`, heartbeat, `POST /messages`).
- Registry → tracker sidecar (`POST /deliver`, `GET /agents`).

The registry stores only the SHA-256 hash of the token; it never stores or returns the
plaintext. The token is distributed to each machine via the Nix home-manager
configuration (analogous to `claude-oauth-token` in `setup.nix`).

Header: `Authorization: Bearer <token>`

All auth failures return the same response regardless of whether the token is missing or
wrong, to avoid leaking information:
```
HTTP 401  {"error": "unauthorized", "message": "invalid or missing token"}
```

### Transport Security

- On the LAN (both subnets), HTTP is acceptable — traffic stays within controlled
  infrastructure with IP forwarding (not exposed to internet).
- Over VPN, the VPN layer (WireGuard/OpenVPN) encrypts traffic; plain HTTP over the
  VPN tunnel is acceptable.
- Optionally, place nginx or Caddy in front of the registry for TLS termination.
  The sidecar-to-registry path can remain HTTP on the LAN.

### Sidecar Binding

The HTTP sidecar binds to `0.0.0.0:19876`. A host-level firewall rule (`iptables` /
macOS `pf`) should restrict port 19876 to `192.168.0.0/24`, `10.27.0.0/24`, and VPN
subnets only.

### Trust Boundary

Individual agents do not authenticate to the registry. Authentication is machine-level
(tracker ↔ registry). An agent cannot forge another agent's identity at the registry
level — the tracker is the trust boundary, enforced by the Unix domain socket being
local-only.

Token compromise: if any machine is compromised, rotate the shared token and redeploy.
Per-machine certificates (mTLS) would isolate the blast radius but add CA management
overhead not warranted for a home-lab.

---

## Decisions

All open questions have been resolved. Decisions are recorded here for posterity.

| # | Question | Decision |
|---|----------|----------|
| 1 | Offline message queue | **Fail fast.** Return `503` immediately. No queue at the registry. Sender is responsible for retry. |
| 2 | Token rotation | **Simultaneous redeploy via Nix.** Update secret in `setup.nix`, run `home-manager switch` on all machines. Key versioning is unnecessary complexity. |
| 3 | mTLS | **Deferred.** Not needed for a trusted home-lab. Revisit if machines ever join outside the trusted network. |
| 4 | Registry HA | **rsync + manual failover.** Periodic `rsync` of the state file to a second machine. Local operation is unaffected when the registry is down. |
| 5 | Agent name uniqueness | **Require `hostname/name` for all remote sends.** Bare names are local-only; the registry never attempts bare-name global resolution. Eliminates all 409 ambiguity without coordination. See updated [Agent Addressing Spec](#agent-addressing-spec). |
| 6 | Status cache freshness | **Push on status change.** Tracker calls `POST /trackers/{id}/agent-update` on every agent status transition. Heartbeat remains the full-sync fallback. See new endpoint below. |
| 7 | Sidecar port conflicts | **One tracker per machine.** `AGENT_TRACKER_HTTP_PORT` env var handles exceptions. No further design needed. |
| 8 | Persistence format | **Flat JSON file with atomic write** (write to temp file, then `os.rename`). No SQLite. Sufficient for < 20 machines. |

---

## Implementation Phases

### Phase 1 — Registry service (standalone)

Implement the registry as a standalone HTTP server (Python stdlib `http.server` or
FastAPI; fits the existing Python ecosystem). Endpoints: `POST /trackers`, heartbeat,
deregistration, `GET /trackers`, `GET /agents`, `GET /agents/{id}`, `GET /healthz`.
Add the background monitor loop for stale/gone transitions. Wire up shared-token auth.
Implement flat-file persistence for restart recovery.

### Phase 2 — Tracker HTTP sidecar

Add the sidecar to the existing tracker daemon as a new thread spawned from
`agent-tracker.py`'s `main()`. Implement `POST /deliver` and `GET /agents`. Extend
`state.py` to expose the sidecar-safe agent snapshot (no tmux/PID fields). Add
`AGENT_TRACKER_HTTP_PORT` and `AGENT_REGISTRY_URL` env var handling.

### Phase 3 — Tracker registration and heartbeat client

Add a background thread in the tracker that calls `POST /trackers` on startup and
`POST /trackers/{id}/heartbeat` every 30 s with the full agent list. Implement the
`404`-triggered re-registration path. Implement exponential backoff for network errors.

### Phase 4 — Extended `send_message` and CLI

Extend `handle_send_message` in `rpc_handler.py` to parse `target_address` and route
to the registry when the hostname differs. Add the registry HTTP client (resolve agent →
post message). Extend `agent-tracker-ctl` to accept `<hostname>/<name>` and bare UUID
targets.

### Key Files for Implementation

- `modules/agent-tracker/agent-tracker.py` — add sidecar thread start in `main()`
- `modules/agent-tracker/rpc_handler.py` — extend `handle_send_message`, add registry client
- `modules/agent-tracker/state.py` — add `get_agents_for_registry()` snapshot helper
- `modules/agent-tracker/agent-tracker-ctl.py` — extend CLI target parsing
- `agent-registry/` — new service (this repo)
