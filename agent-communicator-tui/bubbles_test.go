package main

import (
	"strings"
	"testing"

	"github.com/tanmayvijay/home-manager-core/agent-communicator-tui/internal/tracker"
)

func TestMessagesUseBoxesAndSelectionDot(t *testing.T) {
	m := model{messageSelected: 0, messages: []tracker.Message{{Sender: "alice", Body: "hello"}}}
	view := strings.Join(m.messageLinesForWidth(60), "\n")
	for _, want := range []string{"╭", "╰", "│", "● alice", "hello"} {
		if !strings.Contains(view, want) {
			t.Fatalf("message view missing %q:\n%s", want, view)
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

func TestOutgoingAndIncomingUseDifferentBorderColors(t *testing.T) {
	m := model{}
	incoming := m.messageBorderColor(tracker.Message{Sender: "alice"}, "alice")
	outgoing := m.messageBorderColor(tracker.Message{Sender: "You"}, "alice")
	if incoming == outgoing {
		t.Fatalf("incoming and outgoing colors should differ: %s", incoming)
	}
}
