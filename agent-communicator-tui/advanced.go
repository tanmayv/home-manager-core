package main

import (
	"fmt"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/tanmayvijay/home-manager-core/agent-communicator-tui/internal/tracker"
)

func (m *model) toggleMode() {
	m.mode = (m.mode + 1) % 2
	m.messageOffset = 0
	m.messageSelected = clampSelectedMessage(m.messageSelected, len(m.displayMessages()))
}

func (m model) reloadMessages() tea.Cmd {
	if m.mode == advancedView && m.ownName != "" {
		return loadAllInbox(m.local, m.ownName)
	}
	return loadInbox(m.local, m.ownName, m.currentRow())
}

func (m model) displayMessages() []tracker.Message {
	if m.mode == advancedView {
		return m.allMessages
	}
	return m.messages
}

func (m *model) refreshMergedMessages() {
	if m.mode == advancedView {
		m.allMessages = m.mergeAllMessages(m.inboundAllMessages())
		return
	}
	if conversationKey(m.currentRow()) == "" {
		return
	}
	m.messages = m.mergeSentMessages(m.currentRow(), m.inboundMessagesForCurrent())
}

func (m model) mergeAllMessages(inbound []tracker.Message) []tracker.Message {
	merged := append([]tracker.Message{}, inbound...)
	for _, rec := range m.outbox {
		merged = append(merged, outboxMessage(rec, true))
	}
	for _, row := range m.rows {
		for _, msg := range m.sentMessages[conversationKey(row)] {
			if messageIDExists(merged, msg.MessageID) {
				continue
			}
			copy := msg
			copy.Sender = fmt.Sprintf("%s → %s", fallback(m.ownName, "agent-communicator"), row.Name)
			merged = append(merged, copy)
		}
	}
	return sortMessagesByTimestamp(merged)
}

func (m model) inboundAllMessages() []tracker.Message {
	var inbound []tracker.Message
	for _, msg := range m.allMessages {
		if !m.isSentMessage(msg) {
			inbound = append(inbound, msg)
		}
	}
	return inbound
}

func (m model) isSentMessage(msg tracker.Message) bool {
	for _, sent := range m.sentMessages {
		for _, candidate := range sent {
			if msg.MessageID != "" && msg.MessageID == candidate.MessageID {
				return true
			}
			if msg.MessageID == candidate.MessageID && msg.Timestamp == candidate.Timestamp && msg.Body == candidate.Body {
				return true
			}
		}
	}
	return false
}
