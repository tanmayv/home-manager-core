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
var panelBoxStyle = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(lipgloss.Color("8")).Padding(0, 1)

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
	left := box(m.agentListTitle()+"\n"+m.agentList(leftW-4, panelInnerHeight(bodyH)-1), leftW, bodyH)
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
	innerW := panelInnerWidth(width)
	innerH := panelInnerHeight(height)
	title := titleStyle.Render("Conversation")
	composer := m.composerBox(innerW)
	messageH := max(1, innerH-lineCount(title)-lineCount(composer)-2)
	body := title + "\n" + composer + "\n" + m.messageViewWithHeight(innerW, messageH)
	return box(body, width, height)
}

func (m model) advancedBody(width, height int) string {
	innerW := panelInnerWidth(width)
	innerH := panelInnerHeight(height)
	title := titleStyle.Render("Simple View                                    Advanced View")
	composer := m.composerBox(innerW)
	messageH := max(1, innerH-lineCount(title)-lineCount(composer)-2)
	body := title + "\n" + composer + "\n" + m.messageViewWithHeight(innerW, messageH)
	return box(body, width, height)
}

func (m model) composerBox(width int) string {
	inner := max(1, width-4)
	return composerBoxStyle.Width(inner).MaxWidth(max(1, width)).Render(m.composerView(inner))
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

func (m model) agentListTitle() string {
	title := "Agents"
	if m.agentListLoading {
		frames := []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
		title += " " + mutedStyle.Render(frames[m.agentListFrame%len(frames)])
	}
	return titleStyle.Render(title)
}

func (m model) agentCard(row agentRow, selected bool, width int) string {
	inner := max(8, width-6)
	badge := ""
	if m.hasUnread(row) {
		badge = "●"
	}
	name := truncateCells(row.Name, inner)
	if badge != "" {
		left := truncateCells(row.Name, max(1, inner-2))
		name = left + strings.Repeat(" ", max(1, inner-lipgloss.Width(left)-1)) + badge
	}
	detail := row.Scope
	if row.Scope == "remote" {
		detail += " · " + fallback(row.Hostname, splitHost(row.TargetAddress))
	}
	lines := name + "\n" + mutedStyle.Render(truncateCells(detail, inner))
	style := lipgloss.NewStyle().Width(inner).Border(lipgloss.RoundedBorder()).BorderForeground(agentColors[agentColorIndex(row.Name)]).Padding(0, 1)
	if selected {
		style = style.Background(lipgloss.Color("4")).Foreground(lipgloss.Color("15")).Bold(true)
	}
	return style.Render(lines)
}

func splitHost(target string) string {
	host, _ := splitRemoteTarget(target)
	return host
}

func (m model) agentList(width, height int) string {
	if len(m.rows) == 0 {
		return mutedStyle.Render("no agents")
	}
	visible := max(1, height/agentCardHeight)
	offset := min(max(0, m.agentOffset), max(0, len(m.rows)-visible))
	end := min(len(m.rows), offset+visible)
	var b strings.Builder
	for i := offset; i < end; i++ {
		b.WriteString(m.agentCard(m.rows[i], i == m.selected, width-2))
		if i < end-1 {
			b.WriteString("\n")
		}
	}
	if end < len(m.rows) {
		b.WriteString("\n" + mutedStyle.Render("…"))
	}
	return truncateLines(b.String(), height)
}

func (m model) messageView(width int) string {
	return m.messageViewWithHeight(width, m.messageVisibleLines())
}

func (m model) messageViewWithHeight(width, visible int) string {
	lines := m.messageLinesForWidth(width)
	visible = max(1, visible)
	if len(lines) == 0 {
		return ""
	}
	offset := clampMessageOffset(m.messageOffset, len(lines), visible)
	end := min(len(lines), offset+visible)
	return lipgloss.NewStyle().Width(max(1, width)).Height(visible).MaxHeight(visible).Render(strings.Join(lines[offset:end], "\n"))
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
			lines = append(lines, "")
		}
		lines = append(lines, m.messageBubbleLines(msg, i, wrapWidth)...)
	}
	return lines
}

func sentReadMarker(msg tracker.Message) string {
	if msg.Sender != "You" && !strings.Contains(msg.Sender, "→") && !strings.HasPrefix(msg.Sender, "to ") {
		return ""
	}
	if msg.Read {
		return readStatusStyle.Render("✓✓ ")
	}
	if msg.Notified {
		return "✓✓ "
	}
	if msg.Delivered {
		return "✓ "
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
		return panelInnerWidth(m.width)
	}
	_, mid, _ := m.layoutWidths()
	return panelInnerWidth(mid)
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
		placeholder := "type message"
		if m.agentListStale {
			placeholder = "agent tracker unavailable; sending disabled"
		}
		prompt = prefix + cursor + mutedStyle.Render(placeholder)
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

func truncateLines(s string, height int) string {
	lines := strings.Split(s, "\n")
	if len(lines) > height {
		lines = lines[:height]
	}
	return strings.Join(lines, "\n")
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
func panelInnerWidth(w int) int  { return max(1, w-4) }
func panelInnerHeight(h int) int { return max(1, h-2) }

func box(s string, w, h int) string {
	innerW := panelInnerWidth(w)
	innerH := panelInnerHeight(h)
	return panelBoxStyle.Width(innerW).Height(innerH).MaxWidth(max(1, w)).Render(s)
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
