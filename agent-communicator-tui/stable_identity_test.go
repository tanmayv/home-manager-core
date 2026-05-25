package main

import (
	"encoding/json"
	"testing"

	"github.com/tanmayvijay/home-manager-core/agent-communicator-tui/internal/tracker"
)

func TestTrackerMessageDecodesStableSenderIdentity(t *testing.T) {
	var msg tracker.Message
	data := []byte(`{"sender":"dup","sender_agent_id":"agent-1","sender_tracker_id":"tracker-1","message":"hello","read":false}`)
	if err := json.Unmarshal(data, &msg); err != nil {
		t.Fatalf("unmarshal message: %v", err)
	}
	if msg.SenderAgentID != "agent-1" || msg.SenderTrackerID != "tracker-1" {
		t.Fatalf("sender identity = agent %q tracker %q", msg.SenderAgentID, msg.SenderTrackerID)
	}
}

func TestConversationKeyUsesLocalAgentID(t *testing.T) {
	row1 := agentRow{Name: "dup", Scope: "local", TargetAddress: "dup", AgentID: "agent-1"}
	row2 := agentRow{Name: "dup", Scope: "local", TargetAddress: "dup", AgentID: "agent-2"}

	if got := conversationKey(row1); got != "local:agent-1" {
		t.Fatalf("conversationKey(row1) = %q", got)
	}
	if conversationKey(row1) == conversationKey(row2) {
		t.Fatalf("same-name rows should have distinct keys: %q", conversationKey(row1))
	}
}

func TestConversationKeyUsesRemoteTrackerAndAgentID(t *testing.T) {
	row1 := agentRow{Name: "host/dup", Scope: "remote", TargetAddress: "host-a/dup", TrackerID: "tracker-1", AgentID: "agent-1"}
	row2 := agentRow{Name: "host/dup", Scope: "remote", TargetAddress: "host-a/dup", TrackerID: "tracker-2", AgentID: "agent-1"}
	row3 := agentRow{Name: "host/dup", Scope: "remote", TargetAddress: "host-a/dup", TrackerID: "tracker-1", AgentID: "agent-2"}

	if got := conversationKey(row1); got != "remote:tracker-1:agent-1" {
		t.Fatalf("conversationKey(row1) = %q", got)
	}
	if conversationKey(row1) == conversationKey(row2) || conversationKey(row1) == conversationKey(row3) {
		t.Fatalf("same-name remote rows should have distinct keys: row1=%q row2=%q row3=%q", conversationKey(row1), conversationKey(row2), conversationKey(row3))
	}
}

func TestConversationKeyUsesRemoteHostnameWhenTrackerIDMissing(t *testing.T) {
	row := agentRow{Name: "host/dup", Scope: "remote", TargetAddress: "host-a/dup", AgentID: "agent-1"}
	if got := conversationKey(row); got != "remote:host-a:agent-1" {
		t.Fatalf("conversationKey(row) = %q", got)
	}
}

func TestMakeOutboxRecordStoresTargetIdentity(t *testing.T) {
	row := agentRow{Name: "host/dup", Scope: "remote", TargetAddress: "host-a/dup", AgentID: "agent-1", TrackerID: "tracker-1"}
	rec := makeOutboxRecord("sender", row, "hello")
	if rec.TargetAgentID != "agent-1" || rec.TargetTrackerID != "tracker-1" {
		t.Fatalf("target identity = agent %q tracker %q", rec.TargetAgentID, rec.TargetTrackerID)
	}
}

func TestLegacyOutboxRecordStillMatchesByTargetAddress(t *testing.T) {
	row := agentRow{Name: "dup", Scope: "local", TargetAddress: "dup", AgentID: "agent-1"}
	rec := outboxRecord{ID: "sent-1", Timestamp: "2026-01-01T00:00:00Z", TargetAddress: "dup", Body: "legacy sent"}
	m := model{outbox: []outboxRecord{rec}}

	merged := m.mergeSentMessages(row, nil)
	if len(merged) != 1 || merged[0].Body != "legacy sent" {
		t.Fatalf("merged legacy outbox = %+v", merged)
	}
}

func TestOutboxRecordIdentityMismatchDoesNotFallbackToTargetAddress(t *testing.T) {
	row := agentRow{Name: "dup", Scope: "local", TargetAddress: "dup", AgentID: "agent-1"}
	rec := outboxRecord{ID: "sent-1", TargetAddress: "dup", TargetAgentID: "agent-2"}
	if outboxRecordMatchesRow(rec, row) {
		t.Fatal("identity mismatch should not match by legacy target address")
	}
}

func TestFilterConversationUsesLocalSenderAgentID(t *testing.T) {
	row := agentRow{Name: "dup", Scope: "local", TargetAddress: "dup", AgentID: "agent-1"}
	messages := []tracker.Message{
		{Sender: "dup", SenderAgentID: "agent-1", Body: "for one"},
		{Sender: "dup", SenderAgentID: "agent-2", Body: "for two"},
	}

	filtered := filterConversation(messages, row)
	if len(filtered) != 1 || filtered[0].Body != "for one" {
		t.Fatalf("filtered = %+v", filtered)
	}
}

func TestFilterConversationUsesRemoteSenderTrackerAndAgentID(t *testing.T) {
	row := agentRow{Name: "host/dup", Scope: "remote", TargetAddress: "host/dup", Hostname: "host", AgentName: "dup", AgentID: "agent-1", TrackerID: "tracker-1"}
	messages := []tracker.Message{
		{Sender: "dup (via host)", SenderAgentID: "agent-1", SenderTrackerID: "tracker-1", Body: "for tracker one"},
		{Sender: "dup (via host)", SenderAgentID: "agent-1", SenderTrackerID: "tracker-2", Body: "for tracker two"},
		{Sender: "dup (via host)", SenderAgentID: "agent-2", SenderTrackerID: "tracker-1", Body: "for agent two"},
	}

	filtered := filterConversation(messages, row)
	if len(filtered) != 1 || filtered[0].Body != "for tracker one" {
		t.Fatalf("filtered = %+v", filtered)
	}
}

func TestMessageSenderAgentIDMismatchDoesNotFallbackToDisplayName(t *testing.T) {
	row := agentRow{Name: "dup", Scope: "local", TargetAddress: "dup", AgentID: "agent-1"}
	msg := tracker.Message{Sender: "dup", SenderAgentID: "agent-2", Body: "wrong identity"}
	if messageMatchesRow(msg, row) {
		t.Fatal("mismatched sender_agent_id should not match by display name")
	}
}

func TestLegacyMessageWithoutSenderIDFallsBackToDisplayName(t *testing.T) {
	row := agentRow{Name: "dup", Scope: "local", TargetAddress: "dup", AgentID: "agent-1"}
	msg := tracker.Message{Sender: "dup", Body: "legacy"}
	if !messageMatchesRow(msg, row) {
		t.Fatal("legacy message without sender_agent_id should match by display name")
	}
}
