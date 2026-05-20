package main

import (
	"regexp"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

var linkStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("12")).Underline(true)
var codeStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("11"))
var commentStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("8")).Italic(true)
var keywordStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("13")).Bold(true)
var stringStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("10"))

var urlRE = regexp.MustCompile(`https?://[^\s)]+`)
var mdLinkRE = regexp.MustCompile(`\[([^\]]+)\]\((https?://[^\s)]+)\)`)

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
			out = append(out, "• "+renderInlineMarkdown(strings.TrimSpace(line[2:])))
		case strings.HasPrefix(line, "```"):
			block, next := renderCodeBlock(lines, i)
			out = append(out, block...)
			i = next
		default:
			out = append(out, renderInlineMarkdown(lines[i]))
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

func renderInlineMarkdown(line string) string {
	line = mdLinkRE.ReplaceAllStringFunc(line, func(match string) string {
		parts := mdLinkRE.FindStringSubmatch(match)
		if len(parts) != 3 {
			return match
		}
		return linkStyle.Render(parts[1]) + mutedStyle.Render(" <"+parts[2]+">")
	})
	return urlRE.ReplaceAllStringFunc(line, func(url string) string {
		return linkStyle.Render(url)
	})
}

func renderCodeBlock(lines []string, start int) ([]string, int) {
	lang := strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(lines[start]), "```"))
	var out []string
	for i := start + 1; i < len(lines); i++ {
		if strings.HasPrefix(strings.TrimSpace(lines[i]), "```") {
			return out, i
		}
		out = append(out, "  "+highlightCodeLine(lines[i], lang))
	}
	return out, len(lines) - 1
}

func highlightCodeLine(line, lang string) string {
	trimmed := strings.TrimSpace(line)
	if strings.HasPrefix(trimmed, "#") || strings.HasPrefix(trimmed, "//") {
		return commentStyle.Render(line)
	}
	line = highlightQuotedStrings(line)
	for _, kw := range languageKeywords(lang) {
		line = regexp.MustCompile(`\b`+regexp.QuoteMeta(kw)+`\b`).ReplaceAllStringFunc(line, func(s string) string { return keywordStyle.Render(s) })
	}
	return codeStyle.Render(line)
}

func highlightQuotedStrings(line string) string {
	var b strings.Builder
	inQuote := rune(0)
	start := 0
	for i, r := range line {
		if inQuote == 0 && (r == '"' || r == '\'') {
			b.WriteString(line[start:i])
			inQuote = r
			start = i
			continue
		}
		if inQuote != 0 && r == inQuote {
			b.WriteString(stringStyle.Render(line[start : i+1]))
			inQuote = 0
			start = i + 1
		}
	}
	b.WriteString(line[start:])
	return b.String()
}

func languageKeywords(lang string) []string {
	switch strings.ToLower(strings.Fields(lang + " ")[0]) {
	case "go", "golang":
		return []string{"package", "import", "func", "return", "if", "else", "for", "range", "type", "struct", "var", "const"}
	case "py", "python":
		return []string{"def", "return", "if", "elif", "else", "for", "while", "in", "import", "from", "class", "with", "as"}
	case "nix":
		return []string{"let", "in", "with", "rec", "inherit", "if", "then", "else", "assert"}
	case "sh", "bash", "zsh", "shell":
		return []string{"if", "then", "else", "fi", "for", "do", "done", "case", "esac", "function", "export"}
	default:
		return nil
	}
}
