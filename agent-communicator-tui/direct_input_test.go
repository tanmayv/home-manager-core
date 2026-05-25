package main

import (
	"errors"
	"reflect"
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
)

func TestParseComposerActionDirectInput(t *testing.T) {
	cases := []struct {
		input string
		want  composerAction
	}{
		{"/text hello there", composerAction{Kind: "text", Body: "hello there", Submit: true}},
		{"/text --no-submit draft text", composerAction{Kind: "text", Body: "draft text", Submit: false}},
		{"/key Escape C-c Enter", composerAction{Kind: "key", Keys: []string{"Escape", "C-c", "Enter"}}},
		{"/msg inbox body", composerAction{Kind: "message", Body: "inbox body"}},
		{"plain message", composerAction{Kind: "message", Body: "plain message"}},
	}
	for _, tc := range cases {
		if got := parseComposerAction(tc.input); !reflect.DeepEqual(got, tc.want) {
			t.Fatalf("parseComposerAction(%q) = %#v, want %#v", tc.input, got, tc.want)
		}
	}
}

func TestComposerTextCommandDispatchesSendTextNoOutboxPS(t *testing.T) {
	local := &fakeLocal{}
	row := agentRow{Name: "alpha", Scope: "local"}
	m := model{width: 80, height: 20, rows: []agentRow{row}, local: local}
	m.composer = []rune("/text hello direct")

	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = updated.(model)
	if cmd == nil {
		t.Fatal("direct text should return command")
	}
	updated, _ = m.Update(cmd())
	m = updated.(model)

	if local.textTo != "alpha" || local.textBody != "hello direct" || !local.textSubmit {
		t.Fatalf("text dispatch target=%q body=%q submit=%v", local.textTo, local.textBody, local.textSubmit)
	}
	if local.sentBody != "" || strings.Contains(local.textBody, markdownReplyInstruction) {
		t.Fatalf("direct text used message path or markdown suffix: sent=%q text=%q", local.sentBody, local.textBody)
	}
	if len(m.sentMessages["alpha"]) != 0 {
		t.Fatalf("direct text should not append inbox sent message: %+v", m.sentMessages)
	}
}

func TestComposerTextNoSubmitAndRemoteTargetPreserved(t *testing.T) {
	local := &fakeLocal{}
	row := agentRow{Name: "host/alpha", Scope: "remote", TargetAddress: "host.example/alpha"}
	m := model{width: 80, height: 20, rows: []agentRow{row}, local: local}
	m.composer = []rune("/text --no-submit draft")

	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = updated.(model)
	updated, _ = m.Update(cmd())
	_ = updated.(model)

	if local.textTo != "host.example/alpha" || local.textBody != "draft" || local.textSubmit {
		t.Fatalf("text dispatch target=%q body=%q submit=%v", local.textTo, local.textBody, local.textSubmit)
	}
}

func TestComposerKeyCommandDispatchesSendKeys(t *testing.T) {
	local := &fakeLocal{}
	row := agentRow{Name: "host/alpha", Scope: "remote", TargetAddress: "host.example/alpha"}
	m := model{width: 80, height: 20, rows: []agentRow{row}, local: local}
	m.composer = []rune("/key Escape C-c Enter")

	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = updated.(model)
	updated, _ = m.Update(cmd())
	_ = updated.(model)

	if local.keysTo != "host.example/alpha" || !reflect.DeepEqual(local.keys, []string{"Escape", "C-c", "Enter"}) {
		t.Fatalf("key dispatch target=%q keys=%v", local.keysTo, local.keys)
	}
	if local.sentBody != "" {
		t.Fatalf("key command should not use send-message: %q", local.sentBody)
	}
}

func TestFailedTextCommandRestoresOriginalComposerCommand(t *testing.T) {
	local := &fakeLocal{sendErr: errors.New("boom")}
	row := agentRow{Name: "alpha", Scope: "local"}
	m := model{width: 80, height: 20, rows: []agentRow{row}, local: local}
	m.composer = []rune("/text secret")

	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = updated.(model)
	updated, _ = m.Update(cmd())
	m = updated.(model)

	if got := string(m.composer); got != "/text secret" {
		t.Fatalf("composer after failed /text = %q, want original command", got)
	}
	if local.sentBody != "" {
		t.Fatalf("failed /text should not fall back to send-message: %q", local.sentBody)
	}
}

func TestFailedKeyCommandRestoresOriginalComposerCommand(t *testing.T) {
	local := &fakeLocal{sendErr: errors.New("boom")}
	row := agentRow{Name: "alpha", Scope: "local"}
	m := model{width: 80, height: 20, rows: []agentRow{row}, local: local}
	m.composer = []rune("/key Escape C-c")

	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = updated.(model)
	updated, _ = m.Update(cmd())
	m = updated.(model)

	if got := string(m.composer); got != "/key Escape C-c" {
		t.Fatalf("composer after failed /key = %q, want original command", got)
	}
	if local.sentBody != "" {
		t.Fatalf("failed /key should not fall back to send-message: %q", local.sentBody)
	}
}

func TestDefaultComposerSendMessageRegression(t *testing.T) {
	local := &fakeLocal{}
	m := model{width: 80, height: 20, rows: []agentRow{{Name: "alpha", Scope: "local"}}, local: local}
	m.composer = []rune("hello")

	updated, cmd := m.Update(tea.KeyMsg{Type: tea.KeyEnter})
	m = updated.(model)
	updated, _ = m.Update(cmd())
	m = updated.(model)

	if local.sentTo != "alpha" || !strings.Contains(local.sentBody, markdownReplyInstruction) {
		t.Fatalf("default send-message target=%q body=%q", local.sentTo, local.sentBody)
	}
	if len(m.sentMessages["alpha"]) != 1 || m.sentMessages["alpha"][0].Body != "hello" {
		t.Fatalf("default send should append sent message: %+v", m.sentMessages)
	}
}

func TestComposerHelpMentionsDirectInput(t *testing.T) {
	m := model{}
	view := m.composerView(80)
	if !strings.Contains(view, "/text direct") || !strings.Contains(view, "/key keys") {
		t.Fatalf("composer help missing direct input hints: %q", view)
	}
}
