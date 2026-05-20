package main

import (
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/tanmayvijay/home-manager-core/agent-communicator-tui/internal/tracker"
)

func TestCtrlTTogglesAdvancedViewAndLoadsAllInbox(t *testing.T) {
	local := &fakeLocal{inbox: []tracker.Message{{Sender: "alpha", Body: "a"}, {Sender: "beta", Body: "b"}}}
	m := model{ownName: "agent-communicator", rows: []agentRow{{Name: "alpha", Scope: "local"}}, local: local}
	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyCtrlT})
	m = updated.(model)
	if m.mode != advancedView || cmd == nil {
		t.Fatalf("mode=%v cmd=%v", m.mode, cmd)
	}
	updated, _ = m.Update(cmd())
	m = updated.(model)
	if len(m.allMessages) != 2 {
		t.Fatalf("allMessages = %+v", m.allMessages)
	}
	if local.lastLimit != 50 {
		t.Fatalf("ReadInbox limit = %d, want 50", local.lastLimit)
	}
}

func TestAdvancedComposerShowsSelectedReceiver(t *testing.T) {
	m := model{mode: advancedView, rows: []agentRow{{Name: "alpha"}}}
	view := m.composerView(80)
	if !strings.Contains(view, "@alpha") || !strings.Contains(view, ": ") || !strings.Contains(view, "type message") {
		t.Fatalf("composer = %q", view)
	}
	if agentColorIndex("alpha") != agentColorIndex(m.currentRow().Name) {
		t.Fatalf("composer should color by selected receiver")
	}
	if strings.Index(view, "█") > strings.Index(view, "type message") {
		t.Fatalf("cursor should appear before placeholder: %q", view)
	}
}

func TestAdvancedViewAggregatesInboundAndSentMessages(t *testing.T) {
	m := model{mode: advancedView, width: 100, height: 20, ownName: "agent-communicator", rows: []agentRow{{Name: "alpha", TargetAddress: "alpha"}}, sentMessages: map[string][]tracker.Message{
		"alpha": {{Sender: "You", Body: "out", Timestamp: "2026-05-19T12:01:00Z"}},
	}}
	m.allMessages = m.mergeAllMessages([]tracker.Message{{Sender: "beta", Body: "in", Timestamp: "2026-05-19T12:00:00Z"}})
	view := m.messageView(100)
	for _, want := range []string{"beta → agent-communicator", "to alpha", "in", "out"} {
		if !strings.Contains(view, want) {
			t.Fatalf("advanced view missing %q:\n%s", want, view)
		}
	}
}
