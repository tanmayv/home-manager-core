package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/tanmayvijay/home-manager-core/agent-communicator-tui/internal/tracker"
)

type editorClosed struct{ Err error }

func formatMessageForEditor(msg tracker.Message) string {
	return strings.TrimRight(fmt.Sprintf("# Message from %s\n\n_Time: %s_\n\n%s\n", msg.Sender, msg.Timestamp, msg.Body), "\n") + "\n"
}

func openMessageInEditor(msg tracker.Message) tea.Cmd {
	return func() tea.Msg {
		file, err := os.CreateTemp("", "agent-communicator-*.md")
		if err != nil {
			return editorClosed{Err: err}
		}
		path := file.Name()
		if _, err := file.WriteString(formatMessageForEditor(msg)); err != nil {
			file.Close()
			os.Remove(path)
			return editorClosed{Err: err}
		}
		file.Close()
		editor := os.Getenv("EDITOR")
		if editor == "" {
			editor = "vi"
		}
		return tea.ExecProcess(exec.Command(editor, path), func(err error) tea.Msg {
			os.Remove(path)
			return editorClosed{Err: err}
		})()
	}
}
