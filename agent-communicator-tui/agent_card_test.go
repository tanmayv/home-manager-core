package main

import (
	"strings"
	"testing"

	"github.com/charmbracelet/lipgloss"
)

func TestAgentCardUsesRequestedWidth(t *testing.T) {
	m := model{}
	card := m.agentCard(agentRow{Name: "alpha", Scope: "local"}, false, 40)
	for _, line := range strings.Split(card, "\n") {
		if got := lipgloss.Width(line); got != 40 {
			t.Fatalf("line width=%d want 40 line=%q card=\n%s", got, line, card)
		}
	}
}

func TestSelectedAgentCardUsesDoubleBorder(t *testing.T) {
	m := model{}
	card := m.agentCard(agentRow{Name: "alpha", Scope: "local"}, true, 40)
	if !strings.Contains(card, "╔") || !strings.Contains(card, "╝") {
		t.Fatalf("selected agent card should use double border:\n%s", card)
	}
}

func TestAgentCardUnreadDotStaysOnNameLine(t *testing.T) {
	row := agentRow{Name: "coding-agent", Scope: "local"}
	m := model{unreadRows: map[string]bool{conversationKey(row): true}}
	card := m.agentCard(row, false, 86)
	lines := strings.Split(card, "\n")
	if len(lines) < 3 || !strings.Contains(lines[1], "●") {
		t.Fatalf("unread dot not on name line:\n%s", card)
	}
	if len(lines) > 2 && strings.TrimSpace(lipgloss.NewStyle().Render(lines[2])) == "●" {
		t.Fatalf("unread dot wrapped to detail line:\n%s", card)
	}
}
