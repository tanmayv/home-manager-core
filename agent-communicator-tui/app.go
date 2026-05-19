package main

import (
	"sort"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/tanmayvijay/home-manager-core/agent-communicator-tui/internal/tracker"
)

type viewMode int

const (
	simpleView viewMode = iota
	advancedView
)

type model struct {
	width, height, selected int
	mode                    viewMode
	rows                    []agentRow
	messages                []tracker.Message
	allMessages             []tracker.Message
	outbox                  []outboxRecord
	sentMessages            map[string][]tracker.Message
	messageOffset           int
	messageSelected         int
	messageFocused          bool
	composer                []rune
	err                     error
	eventSeq                int64
	ownName                 string
	local                   localClient
	remote                  remoteClient
}

func newModel(local localClient, remote remoteClient, ownName string) model {
	return model{local: local, remote: remote, ownName: ownName, sentMessages: map[string][]tracker.Message{}}
}
func (m model) Init() tea.Cmd {
	return tea.Batch(loadAgents(m.local, m.remote), loadOutboxCmd(), tickRefresh(), waitEvents(m.local, 0))
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
	case tea.KeyMsg:
		switch msg.Type {
		case tea.KeyCtrlC, tea.KeyCtrlQ:
			return m, tea.Quit
		case tea.KeyCtrlT:
			m.toggleMode()
			m.selectLatestMessage()
			return m, m.reloadMessages()
		case tea.KeyCtrlF:
			return m, switchToAgentPane(m.currentRow())
		case tea.KeyCtrlP:
			if len(m.rows) > 0 {
				m.selected = (m.selected - 1 + len(m.rows)) % len(m.rows)
				m.selectLatestMessage()
				return m, m.reloadMessages()
			}
		case tea.KeyCtrlN:
			if len(m.rows) > 0 {
				m.selected = (m.selected + 1) % len(m.rows)
				m.selectLatestMessage()
				return m, m.reloadMessages()
			}
		case tea.KeyUp:
			m.messageFocused = true
			if m.messageSelected > 0 {
				m.messageSelected--
			}
		case tea.KeyDown:
			m.messageFocused = true
			if m.messageSelected < len(m.displayMessages())-1 {
				m.messageSelected++
			}
		case tea.KeyPgUp, tea.KeyCtrlU:
			m.messageOffset = clampMessageOffset(m.messageOffset-messagePageSize(m.height), len(m.messageLinesForWidth(m.messageContentWidth())), m.messageVisibleLines())
		case tea.KeyPgDown, tea.KeyCtrlD:
			m.messageOffset = clampMessageOffset(m.messageOffset+messagePageSize(m.height), len(m.messageLinesForWidth(m.messageContentWidth())), m.messageVisibleLines())
		case tea.KeyEnter:
			if len(m.rows) > 0 && strings.TrimSpace(string(m.composer)) != "" {
				body := string(m.composer)
				m.composer = nil
				return m, sendCurrentMessage(m.local, m.ownName, m.rows[m.selected], body)
			}
		case tea.KeyBackspace:
			m.messageFocused = false
			if len(m.composer) > 0 {
				m.composer = m.composer[:len(m.composer)-1]
			}
		case tea.KeyCtrlW:
			m.messageFocused = false
			m.composer = deletePreviousWord(m.composer)
		case tea.KeyCtrlR:
			m.selectLatestMessage()
			return m, tea.Batch(loadAgents(m.local, m.remote), loadOutboxCmd())
		case tea.KeyCtrlE:
			messages := m.displayOrderedMessages()
			if len(messages) > 0 {
				return m, openMessageInEditor(messages[m.messageSelected])
			}
		case tea.KeyRunes:
			m.messageFocused = false
			m.composer = append(m.composer, msg.Runes...)
			m.messageOffset = 0
		case tea.KeySpace:
			m.messageFocused = false
			m.composer = append(m.composer, ' ')
			m.messageOffset = 0
		}
	case refreshTick:
		return m, tea.Batch(loadAgents(m.local, m.remote), loadOutboxCmd(), tickRefresh())
	case retryEvents:
		return m, waitEvents(m.local, m.eventSeq)
	case agentsLoaded:
		m.err = msg.Err
		m.rows = filterOwnAgent(msg.Rows, m.ownName)
		if m.selected >= len(m.rows) {
			m.selected = max(0, len(m.rows)-1)
		}
		if len(m.rows) > 0 {
			m.selectLatestMessage()
			return m, m.reloadMessages()
		}
		m.messages = nil
	case inboxLoaded:
		if msg.Err != nil {
			m.err = msg.Err
		} else {
			m.err = nil
			m.messages = m.mergeSentMessages(m.currentRow(), msg.Messages)
			m.selectLatestMessage()
		}
	case allInboxLoaded:
		if msg.Err != nil {
			m.err = msg.Err
		} else {
			m.err = nil
			m.allMessages = m.mergeAllMessages(msg.Messages)
			m.selectLatestMessage()
		}
	case messageSent:
		m.err = msg.Err
		if msg.Err != nil {
			m.composer = []rune(msg.Body)
		} else {
			m.outbox = appendOrReplaceOutbox(m.outbox, msg.Record)
			m.appendSentMessage(msg.Row, msg.Record)
			m.refreshMergedMessages()
			m.selectLatestMessage()
			if len(m.rows) > 0 {
				return m, m.reloadMessages()
			}
		}
	case eventsLoaded:
		if msg.Err == nil {
			m.eventSeq = msg.Result.LastSeq
			m.applyStatusEvents(msg.Result)
			cmds := []tea.Cmd{waitEvents(m.local, m.eventSeq)}
			if len(m.rows) > 0 && shouldReloadForEvents(m.ownName, m.rows[m.selected], msg.Result) {
				cmds = append(cmds, m.reloadMessages())
			}
			return m, tea.Batch(cmds...)
		}
		return m, retryWaitEvents()
	case outboxLoaded:
		if msg.Err != nil {
			m.err = msg.Err
		} else {
			m.outbox = msg.Records
			m.refreshMergedMessages()
		}
	case paneSwitched:
		m.err = msg.Err
	case editorClosed:
		m.err = msg.Err
	}
	return m, nil
}

func (m model) currentRow() agentRow {
	if len(m.rows) == 0 || m.selected < 0 || m.selected >= len(m.rows) {
		return agentRow{}
	}
	return m.rows[m.selected]
}
func conversationKey(row agentRow) string { return rowTarget(row) }

func (m *model) selectLatestMessage() {
	m.messageSelected = 0
	m.messageOffset = 0
}

func clampSelectedMessage(selected, count int) int {
	if count <= 0 {
		return 0
	}
	if selected >= count {
		return count - 1
	}
	return max(0, selected)
}

func (m model) mergeSentMessages(row agentRow, inbound []tracker.Message) []tracker.Message {
	merged := append([]tracker.Message{}, inbound...)
	key := conversationKey(row)
	for _, rec := range m.outbox {
		if rec.TargetAddress == key {
			merged = append(merged, outboxMessage(rec, false))
		}
	}
	for _, sent := range m.sentMessages[key] {
		if !messageIDExists(merged, sent.MessageID) {
			merged = append(merged, sent)
		}
	}
	return sortMessagesByTimestamp(merged)
}

func sortMessagesByTimestamp(messages []tracker.Message) []tracker.Message {
	sort.SliceStable(messages, func(i, j int) bool {
		ti, okI := parseMessageTime(messages[i].Timestamp)
		tj, okJ := parseMessageTime(messages[j].Timestamp)
		if !okI || !okJ || ti.Equal(tj) {
			return false
		}
		return ti.Before(tj)
	})
	return messages
}

func parseMessageTime(value string) (time.Time, bool) {
	if value == "" {
		return time.Time{}, false
	}
	if t, err := time.Parse(time.RFC3339Nano, value); err == nil {
		return t, true
	}
	if t, err := time.Parse(time.RFC3339, value); err == nil {
		return t, true
	}
	return time.Time{}, false
}

func (m model) inboundMessagesForCurrent() []tracker.Message {
	row := m.currentRow()
	key := conversationKey(row)
	var inbound []tracker.Message
	for _, msg := range m.messages {
		isSent := false
		for _, sent := range m.sentMessages[key] {
			if msg.MessageID != "" && msg.MessageID == sent.MessageID {
				isSent = true
				break
			}
			if msg.MessageID == sent.MessageID && msg.Timestamp == sent.Timestamp && msg.Body == sent.Body {
				isSent = true
				break
			}
		}
		if !isSent {
			inbound = append(inbound, msg)
		}
	}
	return inbound
}

func (m *model) appendSentMessage(row agentRow, rec outboxRecord) {
	if rowTarget(row) == "" || rec.ID == "" {
		return
	}
	if m.sentMessages == nil {
		m.sentMessages = map[string][]tracker.Message{}
	}
	key := conversationKey(row)
	if messageIDExists(m.sentMessages[key], rec.ID) {
		return
	}
	m.sentMessages[key] = append(m.sentMessages[key], outboxMessage(rec, false))
}
