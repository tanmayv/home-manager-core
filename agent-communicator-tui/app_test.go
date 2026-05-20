package main

import (
	"bytes"
	"context"
	"errors"
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/tanmayvijay/home-manager-core/agent-communicator-tui/internal/registry"
	"github.com/tanmayvijay/home-manager-core/agent-communicator-tui/internal/tracker"
)

type fakeLocal struct {
	agents     map[string]tracker.Agent
	inbox      []tracker.Message
	lastLimit  int
	sentTo     string
	sentBody   string
	sentSender string
	sentID     string
	sendErr    error
	events     tracker.WaitEventsResult
}

func (f *fakeLocal) List(context.Context) (map[string]tracker.Agent, error) { return f.agents, nil }
func (f *fakeLocal) ReadInbox(_ context.Context, _ string, limit int, _ bool) (tracker.ReadInboxResult, error) {
	f.lastLimit = limit
	return tracker.ReadInboxResult{Mode: "history", Messages: f.inbox}, nil
}
func (f *fakeLocal) SendMessage(_ context.Context, target, body string, _ []tracker.Attachment) error {
	f.sentTo, f.sentBody = target, body
	return f.sendErr
}
func (f *fakeLocal) SendMessageFrom(_ context.Context, sender, target, body string, _ []tracker.Attachment) error {
	f.sentSender, f.sentTo, f.sentBody = sender, target, body
	return f.sendErr
}
func (f *fakeLocal) SendMessageWithID(_ context.Context, sender, target, body, id string, _ []tracker.Attachment) error {
	f.sentSender, f.sentTo, f.sentBody, f.sentID = sender, target, body, id
	return f.sendErr
}
func (f *fakeLocal) WaitEvents(context.Context, tracker.WaitOptions) (tracker.WaitEventsResult, error) {
	return f.events, nil
}

type fakeRemote struct{ agents []registry.Agent }

func (f fakeRemote) ListAgents(context.Context) ([]registry.Agent, error) { return f.agents, nil }
func TestRunPrintsVersion(t *testing.T) {
	var out bytes.Buffer
	if err := run(&out, []string{"--version"}); err != nil {
		t.Fatalf("run --version: %v", err)
	}
	got := out.String()
	if !strings.Contains(got, appName) || !strings.Contains(got, version) {
		t.Fatalf("version output = %q, want app name and version", got)
	}
}
func TestRunRejectsUnknownFlag(t *testing.T) {
	var out bytes.Buffer
	if err := run(&out, []string{"--unknown"}); err == nil {
		t.Fatal("run --unknown succeeded, want error")
	}
}
func TestCtrlNCtrlPNavigationAndInboxLoad(t *testing.T) {
	m := model{messageOffset: 3, rows: []agentRow{{Name: "a", Scope: "local"}, {Name: "b", Scope: "local"}}, local: &fakeLocal{}}
	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyCtrlN})
	m = updated.(model)
	if m.selected != 1 {
		t.Fatalf("selected = %d, want 1", m.selected)
	}
	if cmd == nil {
		t.Fatal("down should request inbox load")
	}
	m.messageOffset = 3
	updated, cmd = m.Update(tea.KeyMsg{Type: tea.KeyCtrlP})
	m = updated.(model)
	if m.selected != 0 {
		t.Fatalf("selected = %d, want 0", m.selected)
	}
	if cmd == nil {
		t.Fatal("up should request inbox load")
	}
}
func TestAgentsLoadedKeepsRowsAndRequestsInbox(t *testing.T) {
	m := model{selected: 5, local: &fakeLocal{}}
	updated, cmd := m.Update(agentsLoaded{Rows: []agentRow{{Name: "a", Scope: "local"}}})
	m = updated.(model)
	if m.selected != 0 || len(m.rows) != 1 {
		t.Fatalf("model = %+v", m)
	}
	if cmd == nil {
		t.Fatal("agentsLoaded should request inbox load")
	}
}
func TestCtrlQQuitsCtrlRRefreshesAndPlainQRTypes(t *testing.T) {
	m := model{local: &fakeLocal{}}
	_, quitCmd := m.Update(tea.KeyMsg{Type: tea.KeyCtrlQ})
	if quitCmd == nil {
		t.Fatal("ctrl+q should quit")
	}
	_, refreshCmd := m.Update(tea.KeyMsg{Type: tea.KeyCtrlR})
	if refreshCmd == nil {
		t.Fatal("ctrl+r should refresh")
	}
	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("qr")})
	m = updated.(model)
	if cmd != nil || string(m.composer) != "qr" {
		t.Fatalf("plain q/r should type into composer, composer=%q cmd=%v", string(m.composer), cmd)
	}
}
func TestComposerAcceptsUnicodeBackspaceAndEnterSends(t *testing.T) {
	local := &fakeLocal{}
	m := model{rows: []agentRow{{Name: "alpha", Scope: "local"}}, local: local}
	updated, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("hé")})
	m = updated.(model)
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("qr")})
	m = updated.(model)
	if string(m.composer) != "héqr" {
		t.Fatalf("composer = %q", string(m.composer))
	}
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyBackspace})
	m = updated.(model)
	if string(m.composer) != "héq" {
		t.Fatalf("composer after backspace = %q", string(m.composer))
	}
	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = updated.(model)
	if string(m.composer) != "" || cmd == nil {
		t.Fatalf("composer=%q cmd=%v, want clear and send cmd", string(m.composer), cmd)
	}
	msg := cmd()
	if sent, ok := msg.(messageSent); !ok || sent.Err != nil {
		t.Fatalf("send msg = %#v", msg)
	}
	if local.sentTo != "alpha" || local.sentBody != "héq\n\n(PS: Reply in markdown format.)" {
		t.Fatalf("sent target/body = %q/%q", local.sentTo, local.sentBody)
	}
}

func TestWrappedSendUsesCommunicatorSenderIdentity(t *testing.T) {
	local := &fakeLocal{}
	m := model{ownName: "agent-communicator", rows: []agentRow{{Name: "alpha", Scope: "local"}}, local: local}
	updated, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("hi")})
	m = updated.(model)
	_, cmd := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	msg := cmd()
	if sent, ok := msg.(messageSent); !ok || sent.Err != nil {
		t.Fatalf("send msg = %#v", msg)
	}
	if local.sentSender != "agent-communicator" || local.sentTo != "alpha" {
		t.Fatalf("sender/target = %q/%q", local.sentSender, local.sentTo)
	}
	if local.sentBody != "hi\n\n(PS: Reply in markdown format.)" {
		t.Fatalf("sent body = %q", local.sentBody)
	}
}

func TestRemoteSendUsesHostQualifiedName(t *testing.T) {
	local := &fakeLocal{}
	row := agentRow{Name: "tanma/agent", TargetAddress: "tanmayvijay.c.googlers.com/agent", Scope: "remote"}
	cmd := sendCurrentMessage(local, "", row, "hello")
	msg := cmd()
	if sent, ok := msg.(messageSent); !ok || sent.Err != nil {
		t.Fatalf("send msg = %#v", msg)
	}
	if local.sentTo != "tanmayvijay.c.googlers.com/agent" || local.sentBody != "hello\n\n(PS: Reply in markdown format.)" {
		t.Fatalf("sent target/body = %q/%q", local.sentTo, local.sentBody)
	}
}

func TestSendFailureRestoresComposer(t *testing.T) {
	m := model{rows: []agentRow{{Name: "alpha", Scope: "local"}}, local: &fakeLocal{sendErr: errors.New("boom")}}
	updated, _ := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("hello")})
	m = updated.(model)
	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = updated.(model)
	m, _ = mustUpdate(m, cmd())
	if string(m.composer) != "hello" || m.err == nil {
		t.Fatalf("composer=%q err=%v", string(m.composer), m.err)
	}
}

func TestMessageSentClearsStaleErrorAndReloadsInbox(t *testing.T) {
	m := model{err: context.Canceled, rows: []agentRow{{Name: "alpha", Scope: "local"}}, local: &fakeLocal{}}
	updated, cmd := m.Update(messageSent{})
	m = updated.(model)
	if m.err != nil {
		t.Fatalf("err = %v, want nil", m.err)
	}
	if cmd == nil {
		t.Fatal("successful send should reload inbox")
	}
}

func TestEventsLoadedUpdatesSeqAndReloadsInbox(t *testing.T) {
	m := model{rows: []agentRow{{Name: "alpha", Scope: "local"}}, local: &fakeLocal{}}
	updated, cmd := m.Update(eventsLoaded{Result: tracker.WaitEventsResult{LastSeq: 4, Events: []tracker.Event{{Seq: 4, Type: "message_delivered", TargetAgentName: "alpha"}}}})
	m = updated.(model)
	if m.eventSeq != 4 {
		t.Fatalf("eventSeq = %d, want 4", m.eventSeq)
	}
	if cmd == nil {
		t.Fatal("events should schedule wait and inbox reload")
	}
}

func TestEventsLoadedGapReloadsInbox(t *testing.T) {
	m := model{rows: []agentRow{{Name: "alpha", Scope: "local"}}, local: &fakeLocal{}}
	updated, cmd := m.Update(eventsLoaded{Result: tracker.WaitEventsResult{LastSeq: 9, Gap: true}})
	m = updated.(model)
	if m.eventSeq != 9 || cmd == nil {
		t.Fatalf("eventSeq=%d cmd=%v", m.eventSeq, cmd)
	}
}

func TestShouldReloadForEventsIgnoresRemoteAndUnrelatedEvents(t *testing.T) {
	result := tracker.WaitEventsResult{Events: []tracker.Event{{TargetAgentName: "other"}}}
	if shouldReloadForEvents("", agentRow{Name: "alpha", Scope: "local"}, result) {
		t.Fatal("unrelated event should not reload selected inbox")
	}
	result.Events[0].TargetAgentName = "alpha"
	if shouldReloadForEvents("", agentRow{Name: "alpha", Scope: "remote"}, result) {
		t.Fatal("remote selection should not reload local inbox")
	}
}

func TestShouldReloadForEventsUsesOwnNameWhenWrapped(t *testing.T) {
	row := agentRow{Name: "selected-peer", Scope: "local"}
	result := tracker.WaitEventsResult{Events: []tracker.Event{{TargetAgentName: "agent-communicator"}}}
	if !shouldReloadForEvents("agent-communicator", row, result) {
		t.Fatal("event targeting communicator should reload selected conversation when wrapped")
	}
}

func TestEventsLoadedErrorSchedulesDelayedRetry(t *testing.T) {
	m := model{eventSeq: 3, local: &fakeLocal{events: tracker.WaitEventsResult{LastSeq: 4}}}
	_, cmd := m.Update(eventsLoaded{Err: errors.New("poll failed")})
	if cmd == nil {
		t.Fatal("wait error should schedule delayed retry")
	}
	if _, ok := cmd().(retryEvents); !ok {
		t.Fatal("error path should emit retryEvents delay marker before retrying waitEvents")
	}
}

func TestRetryEventsStartsWaitEvents(t *testing.T) {
	m := model{eventSeq: 3, local: &fakeLocal{events: tracker.WaitEventsResult{LastSeq: 4}}}
	_, cmd := m.Update(retryEvents{})
	if cmd == nil {
		t.Fatal("retryEvents should start waitEvents")
	}
	if msg, ok := cmd().(eventsLoaded); !ok || msg.Result.LastSeq != 4 {
		t.Fatalf("retry command msg = %#v", msg)
	}
}

func TestCtrlWDeletesPreviousWord(t *testing.T) {
	m := model{composer: []rune("hello world  ")}
	updated, _ := m.Update(tea.KeyMsg{Type: tea.KeyCtrlW})
	m = updated.(model)
	if string(m.composer) != "hello " {
		t.Fatalf("composer = %q, want hello-space", string(m.composer))
	}
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyCtrlW})
	m = updated.(model)
	if string(m.composer) != "" {
		t.Fatalf("composer = %q, want empty", string(m.composer))
	}
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyCtrlW})
	m = updated.(model)
	if string(m.composer) != "" {
		t.Fatalf("empty ctrl+w composer = %q", string(m.composer))
	}
}

func TestLoadInboxUsesOwnInboxAndFiltersBySelectedAgent(t *testing.T) {
	local := &fakeLocal{inbox: []tracker.Message{{Sender: "alpha", Body: "from alpha"}, {Sender: "beta", Body: "from beta"}}}
	msg := loadInbox(local, "agent-communicator", agentRow{Name: "alpha", Scope: "local"})()
	loaded := msg.(inboxLoaded)
	if len(loaded.Messages) != 1 || loaded.Messages[0].Body != "from alpha" {
		t.Fatalf("loaded messages = %+v", loaded.Messages)
	}
	if local.lastLimit != simpleInboxFetchLimit {
		t.Fatalf("ReadInbox limit = %d, want %d", local.lastLimit, simpleInboxFetchLimit)
	}
}

func TestFilterConversationMatchesRemoteSenderFormat(t *testing.T) {
	messages := []tracker.Message{{Sender: "zv2-bmod-agent (via tanmayvijay.c.googlers.com)", Body: "remote"}, {Sender: "other (via tanmayvijay.c.googlers.com)", Body: "other"}}
	row := agentRow{Name: "tanma/zv2-bmod-agent", Scope: "remote", Hostname: "tanmayvijay.c.googlers.com", AgentName: "zv2-bmod-agent", TargetAddress: "tanmayvijay.c.googlers.com/zv2-bmod-agent"}
	filtered := filterConversation(messages, row)
	if len(filtered) != 1 || filtered[0].Body != "remote" {
		t.Fatalf("filtered = %+v", filtered)
	}
}

func TestAgentConfigMenuInteraction(t *testing.T) {
	m := model{
		agentConfigs: map[string]AgentConfig{
			"jetski": {Name: "jetski", Description: "Jetski agent"},
			"pi":     {Name: "pi", Description: "Pi agent"},
		},
		agentConfigKeys:   []string{"jetski", "pi"},
		showingConfigMenu: false,
		configSelected:    0,
	}

	// 1. Press Ctrl-L to open the menu
	updated, _ := m.Update(tea.KeyMsg{Type: tea.KeyCtrlL})
	m = updated.(model)
	if !m.showingConfigMenu {
		t.Fatalf("expected showingConfigMenu to be true")
	}
	if m.configSelected != 0 {
		t.Fatalf("expected configSelected to be 0, got %d", m.configSelected)
	}

	// 2. Press KeyDown to go to next option
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyDown})
	m = updated.(model)
	if m.configSelected != 1 {
		t.Fatalf("expected configSelected to be 1, got %d", m.configSelected)
	}

	// 3. Press KeyDown again (should stay at index 1 because it's capped at len-1)
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyDown})
	m = updated.(model)
	if m.configSelected != 1 {
		t.Fatalf("expected configSelected to be 1, got %d", m.configSelected)
	}

	// 4. Press KeyUp to go back to index 0
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyUp})
	m = updated.(model)
	if m.configSelected != 0 {
		t.Fatalf("expected configSelected to be 0, got %d", m.configSelected)
	}

	// 5. Press Enter to select the config (hides the menu)
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = updated.(model)
	if m.showingConfigMenu {
		t.Fatalf("expected showingConfigMenu to be false after selection")
	}

	// 6. Re-open and Press Esc to close
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyCtrlL})
	m = updated.(model)
	updated, _ = m.Update(tea.KeyMsg{Type: tea.KeyEsc})
	m = updated.(model)
	if m.showingConfigMenu {
		t.Fatalf("expected showingConfigMenu to be false after Esc")
	}
}
