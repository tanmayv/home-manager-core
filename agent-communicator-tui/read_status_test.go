package main

import (
	"strings"
	"testing"

	"github.com/tanmayvijay/home-manager-core/agent-communicator-tui/internal/tracker"
)

func TestApplyReadEventsMarksOutboxRecordRead(t *testing.T) {
	withStateHome(t)
	rec := outboxRecord{ID: "m1", TargetAddress: "alpha", Body: "sent"}
	if err := appendOutbox(rec); err != nil {
		t.Fatalf("appendOutbox: %v", err)
	}
	m := model{ownName: "agent-communicator", rows: []agentRow{{Name: "alpha", TargetAddress: "alpha"}}, outbox: []outboxRecord{rec}}
	m.applyReadEvents(tracker.WaitEventsResult{Events: []tracker.Event{{Type: "message_read", Sender: "agent-communicator", MessageID: "m1"}}})
	if !m.outbox[0].Read {
		t.Fatal("outbox record not marked read")
	}
	reloaded, err := loadOutbox()
	if err != nil || len(reloaded) != 1 || !reloaded[0].Read {
		t.Fatalf("reloaded outbox = %+v err=%v", reloaded, err)
	}
}

func TestSentReadMarkerShowsReadAndUnread(t *testing.T) {
	if !strings.Contains(sentReadMarker(tracker.Message{Sender: "You"}), "✓") {
		t.Fatal("unread sent marker missing")
	}
	if !strings.Contains(sentReadMarker(tracker.Message{Sender: "You", Read: true}), "✓✓") {
		t.Fatal("read sent marker missing")
	}
	if sentReadMarker(tracker.Message{Sender: "agent"}) != "" {
		t.Fatal("incoming message should not get sent read marker")
	}
}
