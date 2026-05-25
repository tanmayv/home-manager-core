# Agent Communicator stable conversation identity implementation plan

## Problem

`agent-communicator` can merge conversations/inboxes when two agents share the same display name. The current TUI primarily identifies conversations by display/target strings:

- `filterConversation(...)` uses `senderMatchesRow(msg.Sender, row)`.
- `senderMatchesRow(...)` compares sender display text to `row.Name` / remote host+agent display text.
- `conversationKey(row)` returns `rowTarget(row)`, which can fall back to display name/target address.
- Outbox/in-memory sent messages are keyed by the same conversation key.

The tracker already persists stable message metadata (`sender_agent_id`, `sender_tracker_id`) for many delivered messages, but `agent-communicator-tui/internal/tracker.Message` does not expose those fields. That forces the UI to use display names for conversation matching.

## Goal

Use stable agent identity for conversation selection and merging whenever available, while preserving backward compatibility for legacy inbox/outbox records that only have display names.

## Non-goals

- Do not require global display-name uniqueness.
- Do not rewrite historical inbox/outbox files.
- Do not remove legacy text matching; keep it only as fallback when stable IDs are unavailable.

## Phase 1: model stable identities and keys

### Changes

1. Extend `tracker.Message` with stable sender metadata:

```go
SenderAgentID   string `json:"sender_agent_id,omitempty"`
SenderTrackerID string `json:"sender_tracker_id,omitempty"`
```

2. Extend `outboxRecord` with stable target metadata for newly sent messages:

```go
TargetAgentID   string `json:"target_agent_id,omitempty"`
TargetTrackerID string `json:"target_tracker_id,omitempty"`
```

3. Populate those fields in `makeOutboxRecord(...)` from `agentRow.AgentID` and `agentRow.TrackerID`.

4. Replace the current `conversationKey(row)` implementation with an identity-first key:

- local with agent ID: `local:<agent_id>`
- remote with tracker ID and agent ID: `remote:<tracker_id>:<agent_id>`
- remote with agent ID but no tracker ID: `remote:<hostname>:<agent_id>`
- fallback: existing `rowTarget(row)`

5. Add a helper for outbox matching, e.g. `outboxRecordMatchesRow(rec, row)`:

- If both record and row have `TargetAgentID`, require ID equality.
- If remote and both have `TargetTrackerID`, require tracker equality too.
- Otherwise fallback to `rec.TargetAddress == rowTarget(row)` for legacy records.

### Tests

Add/adjust tests to prove:

- `conversationKey` differs for same-name rows with different local agent IDs.
- `conversationKey` differs for same-name remote rows with different tracker IDs/agent IDs.
- `makeOutboxRecord` stores target identity fields.
- Existing legacy outbox records without IDs still merge by `TargetAddress`.

## Phase 2: identity-aware inbound filtering

### Changes

1. Add a message-row matcher, e.g. `messageMatchesRow(msg, row)`:

- If `msg.SenderAgentID` and `row.AgentID` are both present:
  - require agent ID equality
  - for remote rows, if both `msg.SenderTrackerID` and `row.TrackerID` are present, require tracker ID equality
  - return false for known ID mismatch (do not fall back to display-name matching)
- If stable IDs are not available, fallback to existing `senderMatchesRow(msg.Sender, row)`.

2. Update `filterConversation(...)` to use `messageMatchesRow(...)` instead of display-only matching.

3. Update `mergeSentMessages(...)`, `appendSentMessage(...)`, and `removeSentMessage(...)` to use identity-aware outbox matching/keying.

4. Keep `senderMatchesRow(...)` available as legacy display matching for old messages and event paths that do not yet include sender IDs.

### Tests

Add tests to prove:

- Two same-name local rows with different `AgentID`s only show their own messages.
- Two same-name remote rows with different `TrackerID`s or `AgentID`s only show their own messages.
- A message with a mismatched `SenderAgentID` does not get included just because `Sender` text matches.
- Legacy messages without `SenderAgentID` still match using existing display-name logic.

## Phase 3: validation and rollout

### Validation commands

Run targeted Go tests:

```bash
cd agent-communicator-tui
go test ./...
```

Run relevant tracker tests only if tracker code changes are introduced. This plan should be TUI-only.

### Manual validation

1. Create or simulate two rows with the same display name and different stable IDs.
2. Put messages from each sender in the communicator inbox with distinct `sender_agent_id` values.
3. Verify selecting each row only shows that row's conversation.
4. Verify old messages without sender IDs still appear through fallback matching.

## Risks and mitigations

- **Legacy messages lack IDs**: keep display-name fallback only when IDs are missing.
- **Outbox records already on disk lack target IDs**: keep `TargetAddress` fallback for old rows.
- **Unread event matching still uses display sender text**: leave as a known limitation unless tracker events are later extended with sender IDs. The main conversation merge bug is fixed by identity-aware message filtering.

## Recommended ownership

- `hm-core-coder`: implement Phase 1 and Phase 2 in small commits/patches, with tests.
- `hm-core-reviewer`: review after each phase and independently run `go test ./...` from `agent-communicator-tui`.
