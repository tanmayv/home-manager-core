package main

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/tanmayvijay/home-manager-core/agent-communicator-tui/internal/tracker"
)

var bubbleBorder = lipgloss.RoundedBorder()

func (m model) messageBubbleLines(msg tracker.Message, index, width int) []string {
	sent := isSentMessage(msg)
	bubbleWidth := min(max(8, width), max(8, (width*78)/100))
	innerWidth := max(4, bubbleWidth-4)
	colorKey := m.messageColorKey(msg)
	lines := []string{m.messageBubbleHeader(msg, index, colorKey)}
	body := msg.Body
	if msg.ContentType == "" || msg.ContentType == "text/markdown" {
		body = renderMarkdown(body, innerWidth)
	}
	lines = append(lines, m.visibleBodyLines(messageBodyLines(body, innerWidth), index)...)
	box := lipgloss.NewStyle().Width(bubbleWidth).Padding(0, 1).Border(bubbleBorder).BorderForeground(bubbleColor(colorKey, index == m.messageSelected))
	if index == m.messageSelected {
		box = box.Bold(true)
	}
	return placeBubble(strings.Split(box.Render(strings.Join(lines, "\n")), "\n"), width, !sent)
}

func (m model) messageBubbleHeader(msg tracker.Message, index int, colorKey string) string {
	selector := ""
	if index == m.messageSelected {
		selector = selectedStyle.Render("● ")
	}
	sender := fallback(msg.Sender, "unknown")
	if m.mode == advancedView && !strings.Contains(sender, "→") && !strings.HasPrefix(sender, "to ") {
		sender += " → " + fallback(m.ownName, "agent-communicator")
	}
	header := selector + sentReadMarker(msg) + agentStyle(colorKey, true).Render(sender)
	if msg.Timestamp != "" {
		header += " " + mutedStyle.Render(msg.Timestamp)
	}
	return header
}

func placeBubble(lines []string, width int, right bool) []string {
	out := make([]string, 0, len(lines))
	for _, line := range lines {
		if right {
			out = append(out, lipgloss.PlaceHorizontal(max(1, width), lipgloss.Right, line))
		} else {
			out = append(out, lipgloss.PlaceHorizontal(max(1, width), lipgloss.Left, line))
		}
	}
	return out
}

func isSentMessage(msg tracker.Message) bool {
	return msg.Sender == "You" || strings.Contains(msg.Sender, "→") || strings.HasPrefix(msg.Sender, "to ")
}

func (m model) messageColorKey(msg tracker.Message) string {
	sender := strings.TrimSpace(msg.Sender)
	if strings.HasPrefix(sender, "to ") {
		return strings.TrimSpace(strings.TrimPrefix(sender, "to "))
	}
	if strings.Contains(sender, "→") {
		parts := strings.Split(sender, "→")
		if strings.TrimSpace(parts[0]) == m.ownName || strings.TrimSpace(parts[0]) == "agent-communicator" {
			return strings.TrimSpace(parts[len(parts)-1])
		}
	}
	return senderColorKey(sender)
}

func bubbleColor(colorKey string, selected bool) lipgloss.Color {
	if selected {
		return lipgloss.Color("10")
	}
	return agentColors[agentColorIndex(colorKey)]
}
