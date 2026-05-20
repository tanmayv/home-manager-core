package main

import (
	"context"
	"errors"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/tanmayvijay/home-manager-core/agent-communicator-tui/internal/tracker"
)

type localClient interface {
	List(context.Context) (map[string]tracker.Agent, error)
	ReadInbox(context.Context, string, int, bool) (tracker.ReadInboxResult, error)
	SendMessage(context.Context, string, string, []tracker.Attachment) error
	SendMessageFrom(context.Context, string, string, string, []tracker.Attachment) error
	WaitEvents(context.Context, tracker.WaitOptions) (tracker.WaitEventsResult, error)
}

type messageIDSender interface {
	SendMessageWithID(context.Context, string, string, string, string, []tracker.Attachment) error
}

type remoteClient interface{}

type agentRow struct{ Name, Scope, Status, CWD, TargetAddress, Hostname, AgentName, TmuxPane string }
type agentsLoaded struct {
	Rows []agentRow
	Err  error
}
type inboxLoaded struct {
	Messages []tracker.Message
	Err      error
}
type allInboxLoaded struct {
	Messages []tracker.Message
	Err      error
}
type messageSent struct {
	Body   string
	Row    agentRow
	Record outboxRecord
	Err    error
}
type eventsLoaded struct {
	Result tracker.WaitEventsResult
	Err    error
}
type refreshTick struct{}
type retryEvents struct{}

func loadInbox(local localClient, inboxOwner string, row agentRow) tea.Cmd {
	return func() tea.Msg {
		if local == nil || row.Name == "" {
			return inboxLoaded{}
		}
		owner := inboxOwner
		if owner == "" && row.Scope == "local" {
			owner = row.Name
		}
		if owner == "" {
			return inboxLoaded{}
		}
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		inbox, err := local.ReadInbox(ctx, owner, 50, false)
		return inboxLoaded{Messages: filterConversation(inbox.Messages, row), Err: err}
	}
}

func loadAllInbox(local localClient, inboxOwner string) tea.Cmd {
	return func() tea.Msg {
		if local == nil || inboxOwner == "" {
			return allInboxLoaded{}
		}
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		inbox, err := local.ReadInbox(ctx, inboxOwner, 50, false)
		return allInboxLoaded{Messages: inbox.Messages, Err: err}
	}
}

func filterConversation(messages []tracker.Message, row agentRow) []tracker.Message {
	if row.Name == "" {
		return messages
	}
	filtered := []tracker.Message{}
	for _, msg := range messages {
		if senderMatchesRow(msg.Sender, row) {
			filtered = append(filtered, msg)
		}
	}
	return filtered
}

func senderMatchesRow(sender string, row agentRow) bool {
	if sender == row.Name || strings.HasPrefix(sender, row.Name+" ") {
		return true
	}
	if row.Scope == "remote" {
		agentName, hostname := row.AgentName, row.Hostname
		address := rowTarget(row)
		if agentName == "" && strings.Contains(address, "/") {
			parts := strings.SplitN(address, "/", 2)
			hostname, agentName = parts[0], parts[1]
		}
		return agentName != "" && hostname != "" && strings.HasPrefix(sender, agentName+" ") && strings.Contains(sender, "(via "+hostname+")")
	}
	return false
}

func filterOwnAgent(rows []agentRow, ownName string) []agentRow {
	if ownName == "" {
		return rows
	}
	filtered := rows[:0]
	for _, row := range rows {
		if row.Name != ownName {
			filtered = append(filtered, row)
		}
	}
	return filtered
}

func deletePreviousWord(value []rune) []rune {
	end := len(value)
	for end > 0 && value[end-1] == ' ' {
		end--
	}
	start := end
	for start > 0 && value[start-1] != ' ' {
		start--
	}
	return value[:start]
}

const markdownReplyInstruction = "PS: Reply in markdown format."

func sendCurrentMessage(local localClient, senderName string, row agentRow, body string) tea.Cmd {
	return sendOutboxRecord(local, senderName, row, makeOutboxRecord(senderName, row, body))
}

func sendOutboxRecord(local localClient, senderName string, row agentRow, record outboxRecord) tea.Cmd {
	return func() tea.Msg {
		if local == nil {
			return messageSent{Body: record.Body, Row: row, Record: record, Err: errors.New("local tracker client unavailable")}
		}
		target := rowTarget(row)
		if strings.TrimSpace(record.Body) == "" || target == "" {
			return messageSent{Body: record.Body, Row: row, Record: record}
		}
		deliveryBody := messageBodyForDelivery(record.Body)
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		var err error
		if withID, ok := local.(messageIDSender); ok {
			err = withID.SendMessageWithID(ctx, senderName, target, deliveryBody, record.ID, nil)
		} else if senderName != "" {
			err = local.SendMessageFrom(ctx, senderName, target, deliveryBody, nil)
		} else {
			err = local.SendMessage(ctx, target, deliveryBody, nil)
		}
		if err == nil {
			err = appendOutbox(record)
		}
		return messageSent{Body: record.Body, Row: row, Record: record, Err: err}
	}
}

func messageBodyForDelivery(body string) string {
	return strings.TrimRight(body, " \t\r\n") + "\n\n(" + markdownReplyInstruction + ")"
}

func waitEvents(local localClient, since int64) tea.Cmd {
	return func() tea.Msg {
		if local == nil {
			return eventsLoaded{}
		}
		ctx, cancel := context.WithTimeout(context.Background(), 35*time.Second)
		defer cancel()
		result, err := local.WaitEvents(ctx, tracker.WaitOptions{Since: since, Timeout: 25 * time.Second})
		return eventsLoaded{Result: result, Err: err}
	}
}

func shouldReloadForEvents(ownName string, row agentRow, result tracker.WaitEventsResult) bool {
	if row.Name == "" {
		return false
	}
	if ownName == "" && row.Scope != "local" {
		return false
	}
	if result.Reset || result.Gap {
		return true
	}
	targetName := row.Name
	if ownName != "" {
		targetName = ownName
	}
	for _, event := range result.Events {
		if event.TargetAgentName == targetName {
			return true
		}
	}
	return false
}

func tickRefresh() tea.Cmd {
	return tea.Tick(refreshInterval, func(time.Time) tea.Msg { return refreshTick{} })
}
func retryWaitEvents() tea.Cmd {
	return tea.Tick(2*time.Second, func(time.Time) tea.Msg { return retryEvents{} })
}
func rowTarget(row agentRow) string {
	if row.TargetAddress != "" {
		return row.TargetAddress
	}
	return row.Name
}
func shortHost(hostname string) string {
	if len([]rune(hostname)) <= 5 {
		return hostname
	}
	return string([]rune(hostname)[:5])
}
func fallback(v, d string) string {
	if v == "" {
		return d
	}
	return v
}
