package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/tanmayvijay/home-manager-core/agent-communicator-tui/internal/tracker"
)

var titleStyle = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("14"))
var selectedStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("10")).Bold(true)
var mutedStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("8"))
var readStatusStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("12"))
var composerBoxStyle = lipgloss.NewStyle().Border(lipgloss.NormalBorder()).Padding(0, 1)

const composerMaxLines = 5

var agentColors = []lipgloss.Color{"10", "14", "13", "11", "12", "9", "6", "5"}

func (m model) View() string {
	if m.width == 0 {
		return "loading..."
	}
	footer := m.footer(m.width)
	bodyH := max(3, m.height-lineCount(footer))
	if m.mode == advancedView {
		return m.advancedBody(m.width, bodyH) + "\n" + footer
	}
	leftW, midW, rightW := m.layoutWidths()
	_ = rightW
	left := box(titleStyle.Render("Agents")+"\n"+m.agentList(leftW), leftW, bodyH)
	mid := m.conversationPanel(midW, bodyH)
	return lipgloss.JoinHorizontal(lipgloss.Top, left, mid) + "\n" + footer
}

func (m model) layoutWidths() (int, int, int) {
	left := max(12, (m.width*30)/100)
	if m.width < 40 {
		left = max(10, m.width/3)
	}
	mid := max(10, m.width-left)
	return left, mid, 0
}

func (m model) conversationPanel(width, height int) string {
	body := titleStyle.Render("Conversation") + "\n" + m.composerBox(width) + "\n" + m.messageView(width)
	return box(body, width, height)
}

func (m model) advancedBody(width, height int) string {
	body := titleStyle.Render("Simple View                                    Advanced View") + "\n" + m.composerBox(width) + "\n" + m.messageView(width)
	return box(body, width, height)
}

func (m model) composerBox(width int) string {
	inner := max(1, width-4)
	return composerBoxStyle.Width(inner).Render(m.composerView(inner))
}

func (m model) footer(width int) string {
	text := "ctrl+t tab · ctrl+n/p receiver · ctrl+f focus agent · ↑/↓ select msg · ctrl+e open · enter send · ctrl+q quit"
	if m.err != nil {
		text = m.err.Error()
	}
	if lipgloss.Width(text) > width {
		text = truncateCells(text, max(1, width-1)) + "…"
	}
	if m.err != nil {
		return lipgloss.NewStyle().Foreground(lipgloss.Color("1")).Render(text)
	}
	return mutedStyle.Render(text)
}

func (m model) agentList(width int) string {
	if len(m.rows) == 0 {
		return mutedStyle.Render("no agents")
	}
	limit := max(3, m.height-3)
	var b strings.Builder
	for i, r := range m.rows {
		if i >= limit {
			b.WriteString(mutedStyle.Render("…") + "\n")
			break
		}
		line := truncateCells(fmt.Sprintf("%s %-6s %s", marker(i == m.selected), r.Scope, r.Name), max(1, width-1))
		line = agentStyle(r.Name, i == m.selected).Render(line)
		b.WriteString(lipgloss.PlaceHorizontal(max(1, width-2), lipgloss.Left, line) + "\n")
	}
	return b.String()
}

func (m model) messageView(width int) string {
	lines := m.messageLinesForWidth(width)
	visible := m.messageVisibleLines()
	if len(lines) == 0 {
		return ""
	}
	offset := clampMessageOffset(m.messageOffset, len(lines), visible)
	end := min(len(lines), offset+visible)
	return lipgloss.NewStyle().Width(max(1, width)).Render(strings.Join(lines[offset:end], "\n"))
}

func (m model) messageLinesForWidth(width int) []string {
	wrapWidth := max(10, width-1)
	messages := m.displayOrderedMessages()
	if len(messages) == 0 {
		if len(m.rows) > 0 && m.rows[m.selected].Scope == "remote" {
			return wrapLine(mutedStyle.Render("No messages. Remote history is in-memory for sent messages only."), wrapWidth)
		}
		return wrapLine(mutedStyle.Render("No messages. Inbox history loads for local agents."), wrapWidth)
	}
	lines := []string{}
	for i, msg := range messages {
		if i > 0 {
			lines = append(lines, mutedStyle.Render("─"))
		}
		prefix := "  "
		if i == m.messageSelected {
			prefix = "> "
		}
		sender := fallback(msg.Sender, "unknown")
		if m.mode == advancedView && !strings.Contains(sender, "→") {
			sender += " → " + fallback(m.ownName, "agent-communicator")
		}
		header := prefix + sentReadMarker(msg) + agentStyle(senderColorKey(sender), true).Render(sender)
		if msg.Timestamp != "" {
			header += " " + mutedStyle.Render(msg.Timestamp)
		}
		lines = append(lines, wrapLine(header, wrapWidth)...)
		body := msg.Body
		if msg.ContentType == "" || msg.ContentType == "text/markdown" {
			body = renderMarkdown(body, max(10, wrapWidth-4))
		}
		bodyLines := messageBodyLines(body, wrapWidth)
		for _, line := range m.visibleBodyLines(bodyLines, i) {
			lines = append(lines, line)
		}
	}
	return lines
}

func sentReadMarker(msg tracker.Message) string {
	if msg.Sender != "You" && !strings.Contains(msg.Sender, "→") {
		return ""
	}
	if msg.Read {
		return readStatusStyle.Render("⇒⇒ ")
	}
	if msg.Notified {
		return "⇒⇒ "
	}
	if msg.Delivered {
		return "→ "
	}
	return ""
}

func messageBodyLines(body string, wrapWidth int) []string {
	var out []string
	for _, line := range strings.Split(body, "\n") {
		out = append(out, wrapLine("    "+line, wrapWidth)...)
	}
	return out
}

func (m model) visibleBodyLines(lines []string, index int) []string {
	if m.mode != advancedView || index == m.messageSelected || index == 0 || len(lines) <= 3 {
		return lines
	}
	return append(append([]string{}, lines[:3]...), mutedStyle.Render("    …"))
}

func (m model) messageContentWidth() int {
	if m.mode == advancedView {
		return max(1, m.width-3)
	}
	_, mid, _ := m.layoutWidths()
	return max(1, mid-3)
}

func (m model) messageChromeHeight() int {
	if m.mode == advancedView {
		return lineCount(titleStyle.Render("Simple View                                    Advanced View") + "\n" + m.composerBox(max(1, m.width)))
	}
	_, mid, _ := m.layoutWidths()
	return lineCount(titleStyle.Render("Conversation") + "\n" + m.composerBox(mid))
}

func (m model) messageVisibleLines() int {
	return max(1, m.height-lineCount(m.footer(max(1, m.width)))-m.messageChromeHeight())
}
func messagePageSize(height int) int             { return max(1, height/2) }
func messageBottomOffset(total, visible int) int { return max(0, total-visible) }
func clampMessageOffset(offset, total, visible int) int {
	maxOffset := messageBottomOffset(total, visible)
	if offset > maxOffset {
		return maxOffset
	}
	return max(0, offset)
}

func (m model) scrollHint() string {
	lines, visible := len(m.messageLinesForWidth(m.messageContentWidth())), m.messageVisibleLines()
	if lines <= visible {
		return mutedStyle.Render("c-u/c-d scroll messages")
	}
	offset := clampMessageOffset(m.messageOffset, lines, visible)
	return mutedStyle.Render(fmt.Sprintf("messages %d-%d/%d · c-u/c-d", offset+1, min(lines, offset+visible), lines))
}

func (m model) composerView(width int) string {
	return lipgloss.NewStyle().Width(max(1, width)).Render(strings.Join(m.composerLines(width), "\n"))
}

func (m model) composerLines(width int) []string {
	focused := !m.messageFocused
	cursor := ""
	if focused {
		cursor = selectedStyle.Render("█")
	}
	prefix := m.composerPrefix()
	prompt := prefix + string(m.composer) + cursor
	if len(m.composer) == 0 {
		prompt = prefix + cursor + mutedStyle.Render("type message")
	}
	wrapped := wrapLine(prompt, max(1, width-1))
	if len(wrapped) > composerMaxLines {
		wrapped = wrapped[len(wrapped)-composerMaxLines:]
	}
	for i := range wrapped {
		wrapped[i] = truncateCells(wrapped[i], max(1, width-1))
	}
	return wrapped
}

func (m model) composerPrefix() string {
	if m.mode != advancedView {
		return mutedStyle.Render("> ")
	}
	name := fallback(m.currentRow().Name, "agent")
	return agentStyle(name, true).Render("@"+name) + mutedStyle.Render(": ")
}

func wrapLine(s string, width int) []string {
	if lipgloss.Width(s) <= width {
		return []string{s}
	}
	words := strings.Fields(s)
	if len(words) == 0 {
		return []string{""}
	}
	var lines []string
	current := ""
	for _, word := range words {
		candidate := strings.TrimSpace(current + " " + word)
		if lipgloss.Width(candidate) <= width {
			current = candidate
			continue
		}
		if current != "" {
			lines = append(lines, current)
		}
		for lipgloss.Width(word) > width {
			part := truncateCells(word, width)
			lines = append(lines, part)
			word = strings.TrimPrefix(word, part)
		}
		current = word
	}
	if current != "" {
		lines = append(lines, current)
	}
	return lines
}
func truncateCells(s string, width int) string {
	var b strings.Builder
	for _, r := range s {
		if lipgloss.Width(b.String()+string(r)) > width {
			break
		}
		b.WriteRune(r)
	}
	return b.String()
}
func marker(selected bool) string {
	if selected {
		return ">"
	}
	return " "
}
func box(s string, w, h int) string {
	return lipgloss.NewStyle().Width(max(1, w)).Height(max(1, h)).Render(s)
}
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
