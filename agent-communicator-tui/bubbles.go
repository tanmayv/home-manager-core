package main

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/tanmayvijay/home-manager-core/agent-communicator-tui/internal/tracker"
)

var bubbleBorder = lipgloss.RoundedBorder()

func (m model) messageBubbleLines(msg tracker.Message, index, width int) []string {
	colorKey := m.messageColorKey(msg)
	innerWidth := max(4, width-6)
	lines := []string{m.messageHeader(msg, index, colorKey, innerWidth)}
	body := msg.Body
	if msg.ContentType == "" || msg.ContentType == "text/markdown" {
		body = renderMarkdown(body, innerWidth)
	}
	lines = append(lines, m.visibleBodyLines(bubbleBodyLines(body, innerWidth), index)...)
	return renderBubble(lines, innerWidth, m.messageBorderColor(msg, colorKey), isSentMessage(msg))
}

func (m model) messageHeader(msg tracker.Message, index int, colorKey string, width int) string {
	selector := ""
	if index == m.messageSelected {
		selector = selectedStyle.Render("● ")
	}
	sender := fallback(msg.Sender, "unknown")
	if m.mode == advancedView && !strings.Contains(sender, "→") && !strings.HasPrefix(sender, "to ") {
		sender += " → " + fallback(m.ownName, "agent-communicator")
	}
	header := selector + sentReadMarker(msg) + agentStyle(colorKey, true).Render(truncateCells(sender, max(1, width-25)))
	if ts := formatDisplayTime(msg.Timestamp); ts != "" && lipgloss.Width(header)+1 < width {
		header += " " + mutedStyle.Render(truncateCells(ts, width-lipgloss.Width(header)-1))
	}
	return header
}

func renderBubble(lines []string, innerWidth int, color lipgloss.Color, outgoing bool) []string {
	border := lipgloss.NewStyle().Foreground(color)
	left, right := "│", "│"
	if outgoing {
		left = "║"
	} else {
		right = "║"
	}
	out := []string{border.Render("╭" + strings.Repeat("─", innerWidth+2) + "╮")}
	for _, line := range lines {
		cell := lipgloss.PlaceHorizontal(innerWidth, lipgloss.Left, truncateCells(line, innerWidth))
		out = append(out, border.Render(left)+" "+cell+" "+border.Render(right))
	}
	out = append(out, border.Render("╰"+strings.Repeat("─", innerWidth+2)+"╯"))
	return out
}

func bubbleBodyLines(body string, wrapWidth int) []string {
	var out []string
	for _, line := range strings.Split(body, "\n") {
		out = append(out, wrapLine(line, wrapWidth)...)
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

func (m model) messageBorderColor(msg tracker.Message, colorKey string) lipgloss.Color {
	if isSentMessage(msg) {
		return lipgloss.Color("12")
	}
	return agentColors[agentColorIndex(colorKey)]
}
