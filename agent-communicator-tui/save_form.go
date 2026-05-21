package main

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type agentSaved struct {
	Name string
	Err  error
}

func (m *model) initSaveForm() {
	if len(m.rows) == 0 || m.selected >= len(m.rows) {
		return
	}
	row := m.rows[m.selected]

	m.showingSaveForm = true
	m.saveFormIndex = 0

	m.saveFormInputs = make([]textinput.Model, 4)

	// 1. Prepopulate Name
	nameInput := textinput.New()
	cleanName := row.AgentName
	if strings.Contains(cleanName, "-agent-") {
		cleanName = strings.Split(cleanName, "-agent-")[0]
	}
	nameInput.SetValue(cleanName)
	nameInput.Placeholder = "Agent Configuration Name"
	nameInput.Focus()
	m.saveFormInputs[0] = nameInput

	// 2. Prepopulate Description
	descInput := textinput.New()
	descInput.SetValue(fmt.Sprintf("Remote-saved configuration for agent %s in %s", cleanName, row.CWD))
	descInput.Placeholder = "Description"
	m.saveFormInputs[1] = descInput

	// 3. Prepopulate Command
	cmdInput := textinput.New()
	cmdInput.SetValue(row.AgentCmd)
	cmdInput.Placeholder = "Launcher Command (e.g., cli)"
	m.saveFormInputs[2] = cmdInput

	// 4. Prepopulate CWD
	cwdInput := textinput.New()
	cwdInput.SetValue(row.CWD)
	cwdInput.Placeholder = "Working Directory"
	m.saveFormInputs[3] = cwdInput
}

func (m model) updateSaveForm(msg tea.Msg) (model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.Type {
		case tea.KeyEsc:
			m.showingSaveForm = false
			return m, nil
		case tea.KeyTab:
			m.saveFormIndex = (m.saveFormIndex + 1) % 6
			m.focusSaveFormInput()
			return m, nil
		case tea.KeyShiftTab:
			m.saveFormIndex = (m.saveFormIndex - 1 + 6) % 6
			m.focusSaveFormInput()
			return m, nil
		case tea.KeyEnter:
			if m.saveFormIndex == 4 { // Save Button
				m.showingSaveForm = false
				row := m.rows[m.selected]
				return m, saveAgentCmd(
					m.remote,
					row.AgentID,
					m.saveFormInputs[0].Value(),
					m.saveFormInputs[2].Value(),
					m.saveFormInputs[1].Value(),
					m.saveFormInputs[3].Value(),
				)
			}
			if m.saveFormIndex == 5 { // Cancel Button
				m.showingSaveForm = false
				return m, nil
			}
			// Otherwise advance focus
			m.saveFormIndex = (m.saveFormIndex + 1) % 6
			m.focusSaveFormInput()
			return m, nil
		}
	}

	// Update active text inputs
	for i := range m.saveFormInputs {
		if i == m.saveFormIndex {
			var cmd tea.Cmd
			m.saveFormInputs[i], cmd = m.saveFormInputs[i].Update(msg)
			cmds = append(cmds, cmd)
		}
	}

	return m, tea.Batch(cmds...)
}

func (m *model) focusSaveFormInput() {
	for i := range m.saveFormInputs {
		if i == m.saveFormIndex {
			m.saveFormInputs[i].Focus()
		} else {
			m.saveFormInputs[i].Blur()
		}
	}
}

func (m model) renderSaveForm() string {
	var b strings.Builder

	b.WriteString("Save Agent Configuration\n\n")

	labels := []string{"Name:", "Description:", "Command:", "CWD:"}
	for i := range m.saveFormInputs {
		style := lipgloss.NewStyle()
		if i == m.saveFormIndex {
			style = style.Foreground(palette.Blue)
		}
		b.WriteString(style.Render(labels[i]) + "\n")
		b.WriteString(m.saveFormInputs[i].View() + "\n\n")
	}

	// Render Buttons
	saveStyle := lipgloss.NewStyle().Padding(0, 2)
	cancelStyle := lipgloss.NewStyle().Padding(0, 2)

	if m.saveFormIndex == 4 {
		saveStyle = saveStyle.Background(palette.Blue).Foreground(palette.Base)
	} else {
		saveStyle = saveStyle.Border(lipgloss.NormalBorder()).BorderForeground(palette.Overlay0)
	}

	if m.saveFormIndex == 5 {
		cancelStyle = cancelStyle.Background(palette.Red).Foreground(palette.Base)
	} else {
		cancelStyle = cancelStyle.Border(lipgloss.NormalBorder()).BorderForeground(palette.Overlay0)
	}

	buttons := lipgloss.JoinHorizontal(lipgloss.Left,
		saveStyle.Render("Save"),
		"  ",
		cancelStyle.Render("Cancel"),
	)
	b.WriteString("\n" + buttons)

	// Wrap in a box
	boxStyle := lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(palette.Blue).
		Padding(1, 3).
		Width(60)

	return boxStyle.Render(b.String())
}

func saveAgentCmd(remote remoteClient, agentToSave, agentName, command, description, cwd string) tea.Cmd {
	return func() tea.Msg {
		if remote == nil {
			return agentSaved{Err: fmt.Errorf("registry connection unavailable")}
		}
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		err := remote.SaveAgent(ctx, agentToSave, agentName, command, description, cwd)
		return agentSaved{Name: agentName, Err: err}
	}
}
