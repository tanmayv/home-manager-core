package main

import (
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
)

func TestCtrlFAttemptsPaneSwitchForSelectedAgent(t *testing.T) {
	m := model{rows: []agentRow{{Name: "alpha", Scope: "local"}}}
	_, cmd := m.Update(tea.KeyMsg{Type: tea.KeyCtrlF})
	if cmd == nil {
		t.Fatal("ctrl+f should attempt pane switch")
	}
	msg := cmd().(paneSwitched)
	if msg.Err == nil || !strings.Contains(msg.Err.Error(), "no tmux pane") {
		t.Fatalf("pane switch msg = %#v", msg)
	}
}

func TestCtrlFWorksInAdvancedViewForSelectedReceiver(t *testing.T) {
	m := model{mode: advancedView, rows: []agentRow{{Name: "alpha", Scope: "remote"}}}
	_, cmd := m.Update(tea.KeyMsg{Type: tea.KeyCtrlF})
	if cmd == nil {
		t.Fatal("ctrl+f should attempt pane switch in advanced view")
	}
	msg := cmd().(paneSwitched)
	if msg.Err == nil || !strings.Contains(msg.Err.Error(), "remote agent") {
		t.Fatalf("pane switch msg = %#v", msg)
	}
}

func TestRowFromCtlAgentKeepsLocalTmuxPane(t *testing.T) {
	row := rowFromCtlAgent("alpha", ctlAgent{Scope: "local", TmuxPane: "%7"})
	if row.TmuxPane != "%7" {
		t.Fatalf("row = %+v", row)
	}
}
