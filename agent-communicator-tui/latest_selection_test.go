package main

import (
	"testing"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/tanmayvijay/home-manager-core/agent-communicator-tui/internal/tracker"
)

func TestSimpleInboxLoadSelectsLatestAndBottom(t *testing.T) {
	m := model{width: 80, height: 10, rows: []agentRow{{Name: "alpha", Scope: "local"}}}
	updated, _ := m.Update(inboxLoaded{Messages: []tracker.Message{{Sender: "alpha", Body: "old"}, {Sender: "alpha", Body: "new"}}})
	m = updated.(model)
	if m.messageSelected != 1 {
		t.Fatalf("selected = %d, want latest", m.messageSelected)
	}
	want := messageBottomOffset(len(m.messageLinesForWidth(m.messageContentWidth())), m.messageVisibleLines())
	if m.messageOffset != want {
		t.Fatalf("offset = %d, want bottom %d", m.messageOffset, want)
	}
}

func TestAdvancedInboxLoadSelectsLatestAndBottom(t *testing.T) {
	m := model{mode: advancedView, width: 80, height: 10}
	updated, _ := m.Update(allInboxLoaded{Messages: []tracker.Message{{Sender: "a", Body: "old"}, {Sender: "b", Body: "new"}}})
	m = updated.(model)
	if m.messageSelected != 1 {
		t.Fatalf("selected = %d, want latest", m.messageSelected)
	}
}

func TestToggleToAdvancedSelectsLatest(t *testing.T) {
	local := &fakeLocal{inbox: []tracker.Message{{Sender: "a", Body: "old"}, {Sender: "b", Body: "new"}}}
	m := model{width: 80, height: 10, ownName: "agent-communicator", rows: []agentRow{{Name: "alpha", Scope: "local"}}, local: local}
	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyCtrlT})
	m = updated.(model)
	updated, _ = m.Update(cmd())
	m = updated.(model)
	if m.mode != advancedView || m.messageSelected != 1 {
		t.Fatalf("mode=%v selected=%d", m.mode, m.messageSelected)
	}
}

func TestAgentSwitchReloadSelectsLatest(t *testing.T) {
	local := &fakeLocal{inbox: []tracker.Message{{Sender: "beta", Body: "old"}, {Sender: "beta", Body: "new"}}}
	m := model{width: 80, height: 10, selected: 0, rows: []agentRow{{Name: "alpha", Scope: "local"}, {Name: "beta", Scope: "local"}}, local: local}
	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyCtrlN})
	m = updated.(model)
	updated, _ = m.Update(cmd())
	m = updated.(model)
	if m.selected != 1 || m.messageSelected != 1 {
		t.Fatalf("agent=%d message=%d", m.selected, m.messageSelected)
	}
}
