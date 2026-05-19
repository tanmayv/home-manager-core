package main

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
)

func senderColorKey(sender string) string {
	if strings.Contains(sender, "→") {
		return strings.TrimSpace(strings.SplitN(sender, "→", 2)[0])
	}
	return strings.TrimSpace(sender)
}

func agentStyle(name string, bold bool) lipgloss.Style {
	style := lipgloss.NewStyle().Foreground(agentColors[agentColorIndex(name)])
	if bold {
		style = style.Bold(true)
	}
	return style
}

func agentColorIndex(name string) int {
	if name == "" {
		return 0
	}
	h := 0
	for _, r := range name {
		h = (h*31 + int(r)) % len(agentColors)
	}
	return h
}

func lineCount(s string) int {
	if s == "" {
		return 0
	}
	return strings.Count(s, "\n") + 1
}
