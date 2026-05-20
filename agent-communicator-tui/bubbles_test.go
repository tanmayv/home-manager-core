package main

import (
	"strings"
	"testing"

	"github.com/charmbracelet/lipgloss"
	"github.com/tanmayvijay/home-manager-core/agent-communicator-tui/internal/tracker"
)

func TestMessageBubblesUseRoundedBordersAndSelectionDot(t *testing.T) {
	m := model{messageSelected: 0, messages: []tracker.Message{{Sender: "alice", Body: "hello"}}}
	view := strings.Join(m.messageLinesForWidth(60), "\n")
	for _, want := range []string{"╭", "╰", "● alice", "hello"} {
		if !strings.Contains(view, want) {
			t.Fatalf("bubble missing %q:\n%s", want, view)
		}
	}
}

func TestAdvancedBubblesColorByConversationPartner(t *testing.T) {
	m := model{mode: advancedView, ownName: "agent-communicator"}
	if m.messageColorKey(tracker.Message{Sender: "alice"}) != "alice" {
		t.Fatal("inbound should color by sender")
	}
	if m.messageColorKey(tracker.Message{Sender: "to bob"}) != "bob" {
		t.Fatal("outbound should color by receiver")
	}
	if m.messageColorKey(tracker.Message{Sender: "agent-communicator → carol"}) != "carol" {
		t.Fatal("legacy outbound should color by receiver")
	}
}

func TestIncomingBubbleAlignsRightAndSentAlignsLeft(t *testing.T) {
	incoming := model{messages: []tracker.Message{{Sender: "alice", Body: "hi"}}}.messageLinesForWidth(60)
	if len(incoming) == 0 || !strings.HasPrefix(incoming[0], " ") {
		t.Fatalf("incoming bubble should be right aligned: %#v", incoming)
	}
	sent := model{messages: []tracker.Message{{Sender: "You", Body: "sent"}}}.messageLinesForWidth(60)
	if len(sent) == 0 || strings.HasPrefix(sent[0], " ") {
		t.Fatalf("sent bubble should be left aligned: %#v", sent)
	}
	for _, line := range append(incoming, sent...) {
		if lipgloss.Width(line) > 59 {
			t.Fatalf("line width %d > 59: %q", lipgloss.Width(line), line)
		}
	}
}
