package main

import (
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/tanmayvijay/home-manager-core/agent-communicator-tui/internal/tracker"
)

func TestRowFromTrackerAgentKeepsLocalTmuxPane(t *testing.T) {
	row := rowFromTrackerAgent("alpha", tracker.Agent{Scope: "local", TmuxPane: "%7"})
	if row.TmuxPane != "%7" {
		t.Fatalf("row = %+v", row)
	}
}

func TestCtrlEnterAttemptsPaneSwitchForSelectedLocalSender(t *testing.T) {
	m := model{rows: []agentRow{{Name: "alpha", Scope: "local"}}, messages: []tracker.Message{{Sender: "alpha", Body: "hi"}}}
	_, cmd := m.Update(tea.KeyMsg{Type: tea.KeyCtrlJ})
	if cmd == nil {
		t.Fatal("ctrl+enter should attempt pane switch")
	}
	msg := cmd().(paneSwitched)
	if msg.Err == nil || !strings.Contains(msg.Err.Error(), "no tmux pane") {
		t.Fatalf("pane switch msg = %#v", msg)
	}
}

func TestCtrlEnterRejectsRemoteOrOutgoingSender(t *testing.T) {
	m := model{rows: []agentRow{{Name: "alpha", Scope: "remote"}}, messages: []tracker.Message{{Sender: "You", Body: "hi"}}}
	_, cmd := m.Update(tea.KeyMsg{Type: tea.KeyCtrlJ})
	if cmd == nil {
		t.Fatal("ctrl+enter should return error command")
	}
	msg := cmd().(paneSwitched)
	if msg.Err == nil || !strings.Contains(msg.Err.Error(), "not a local agent") {
		t.Fatalf("pane switch msg = %#v", msg)
	}
}
