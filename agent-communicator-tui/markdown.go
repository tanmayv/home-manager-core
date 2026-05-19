package main

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
)

func renderMarkdown(s string, width int) string {
	lines := strings.Split(strings.ReplaceAll(s, "**", ""), "\n")
	var out []string
	for i := 0; i < len(lines); i++ {
		line := strings.TrimSpace(lines[i])
		switch {
		case strings.HasPrefix(line, "#"):
			out = append(out, titleStyle.Render(strings.TrimSpace(strings.TrimLeft(line, "#"))))
		case isMarkdownTableStart(lines, i):
			table, next := renderMarkdownTable(lines, i)
			out = append(out, table...)
			i = next - 1
		case strings.HasPrefix(line, "- ") || strings.HasPrefix(line, "* "):
			out = append(out, "• "+strings.TrimSpace(line[2:]))
		case strings.HasPrefix(line, "```"):
			block, next := renderCodeBlock(lines, i)
			out = append(out, block...)
			i = next
		default:
			out = append(out, lines[i])
		}
	}
	return strings.Join(out, "\n")
}

func isMarkdownTableStart(lines []string, i int) bool {
	return i+1 < len(lines) && strings.Contains(lines[i], "|") && isMarkdownSeparator(lines[i+1])
}

func isMarkdownSeparator(line string) bool {
	line = strings.TrimSpace(line)
	if !strings.Contains(line, "|") {
		return false
	}
	for _, r := range strings.ReplaceAll(line, "|", "") {
		if r != '-' && r != ':' && r != ' ' {
			return false
		}
	}
	return true
}

func renderMarkdownTable(lines []string, start int) ([]string, int) {
	var rows [][]string
	i := start
	for ; i < len(lines) && strings.Contains(lines[i], "|"); i++ {
		if i == start+1 && isMarkdownSeparator(lines[i]) {
			continue
		}
		rows = append(rows, splitTableRow(lines[i]))
	}
	widths := tableWidths(rows)
	out := make([]string, 0, len(rows)+1)
	for idx, row := range rows {
		out = append(out, formatTableRow(row, widths))
		if idx == 0 {
			out = append(out, formatTableSeparator(widths))
		}
	}
	return out, i
}

func splitTableRow(line string) []string {
	line = strings.Trim(strings.TrimSpace(line), "|")
	parts := strings.Split(line, "|")
	for i := range parts {
		parts[i] = strings.TrimSpace(parts[i])
	}
	return parts
}

func tableWidths(rows [][]string) []int {
	var widths []int
	for _, row := range rows {
		for i, cell := range row {
			for len(widths) <= i {
				widths = append(widths, 0)
			}
			widths[i] = max(widths[i], lipgloss.Width(cell))
		}
	}
	return widths
}

func formatTableRow(row []string, widths []int) string {
	cells := make([]string, len(widths))
	for i := range widths {
		cell := ""
		if i < len(row) {
			cell = row[i]
		}
		cells[i] = lipgloss.PlaceHorizontal(widths[i], lipgloss.Left, cell)
	}
	return "│ " + strings.Join(cells, " │ ") + " │"
}

func formatTableSeparator(widths []int) string {
	parts := make([]string, len(widths))
	for i, w := range widths {
		parts[i] = strings.Repeat("─", w+2)
	}
	return "├" + strings.Join(parts, "┼") + "┤"
}

func renderCodeBlock(lines []string, start int) ([]string, int) {
	var out []string
	for i := start + 1; i < len(lines); i++ {
		if strings.HasPrefix(strings.TrimSpace(lines[i]), "```") {
			return out, i
		}
		out = append(out, "  "+lines[i])
	}
	return out, len(lines) - 1
}
