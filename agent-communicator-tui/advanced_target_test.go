package main

import (
	"testing"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/tanmayvijay/home-manager-core/agent-communicator-tui/internal/tracker"
)

func TestAdvancedSelectionSetsComposerTargetToSender(t *testing.T) {
	m := model{mode: advancedView, selected: 0, rows: []agentRow{{Name: "alice", Scope: "local"}, {Name: "bob", Scope: "local"}}, allMessages: []tracker.Message{{Sender: "bob", Body: "old"}, {Sender: "alice", Body: "new"}}}
	m.selectLatestMessage()
	if m.selected != 0 {
		t.Fatalf("latest sender selected row = %d, want alice row 0", m.selected)
	}
	updated, _ := m.Update(tea.KeyMsg{Type: tea.KeyDown})
	m = updated.(model)
	if m.selected != 1 {
		t.Fatalf("older selected sender row = %d, want bob row 1", m.selected)
	}
}

func TestAdvancedSelectionUsesSentMessageTarget(t *testing.T) {
	m := model{mode: advancedView, selected: 0, ownName: "agent-communicator", rows: []agentRow{{Name: "alice", Scope: "local"}, {Name: "bob", Scope: "local"}}, allMessages: []tracker.Message{{Sender: "to bob", Body: "sent"}}}
	m.selectLatestMessage()
	if m.selected != 1 {
		t.Fatalf("sent target selected row = %d, want bob row 1", m.selected)
	}
}

func TestAdvancedSelectionSetsRemoteTargetToSender(t *testing.T) {
	row := agentRow{Name: "dawns/alice", Scope: "remote", Hostname: "dawnstar", AgentName: "alice", TargetAddress: "dawnstar/alice"}
	m := model{mode: advancedView, rows: []agentRow{row}, allMessages: []tracker.Message{{Sender: "alice (via dawnstar)", Body: "remote"}}}
	m.selectLatestMessage()
	if m.selected != 0 {
		t.Fatalf("remote sender selected row = %d, want 0", m.selected)
	}
}
