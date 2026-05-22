package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"strings"
	"time"

	"github.com/tanmayvijay/home-manager-extensions/agent-communicator-web/tracker"
)

var (
	port          int
	socketPath    string
	client        *tracker.Client
	broker        *EventBroker
	registryProxy *httputil.ReverseProxy
)

func main() {
	flag.IntVar(&port, "port", 8282, "HTTP REST server listening port")
	flag.StringVar(&socketPath, "socket", "", "Path to agent-tracker Unix domain socket")
	flag.Parse()

	// Initialize RPC socket client
	var err error
	client, err = tracker.NewClient(socketPath)
	if err != nil {
		log.Fatalf("Failed to initialize tracker client: %v", err)
	}

	log.Printf("Starting agent-communicator-web REST broker on port %d", port)
	log.Printf("Connecting to agent-tracker socket at: %s", client.SocketPath)

	// Initialize and start event broker
	broker = NewEventBroker()
	go broker.Start()

	// Start background event poller
	go pollTrackerEvents(broker)

	// Initialize Registry Reverse Proxy (port 8182)
	target, err := url.Parse("http://localhost:8182")
	if err != nil {
		log.Fatalf("Failed to parse registry target URL: %v", err)
	}
	registryProxy = httputil.NewSingleHostReverseProxy(target)
	originalDirector := registryProxy.Director
	registryProxy.Director = func(req *http.Request) {
		originalDirector(req)
		req.URL.Path = strings.TrimPrefix(req.URL.Path, "/api/registry")
		if req.URL.Path == "" {
			req.URL.Path = "/"
		}
		req.Host = target.Host
	}

	// Serve index HTML at root path
	http.HandleFunc("/", handleIndex)

	// Register REST endpoints
	http.HandleFunc("/api/agents", handleListAgents)
	http.HandleFunc("/api/inbox", handleReadInbox)
	http.HandleFunc("/api/send", handleSendMessage)
	http.HandleFunc("/api/events", handleEvents)
	http.HandleFunc("/api/registry/", handleRegistryProxy)

	// Listen and serve
	addr := fmt.Sprintf(":%d", port)
	if err := http.ListenAndServe(addr, nil); err != nil {
		log.Fatalf("Server error: %v", err)
	}
}

func handleListAgents(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	agents, err := client.List(r.Context())
	if err != nil {
		log.Printf("List error: %v", err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(agents); err != nil {
		log.Printf("JSON encode error: %v", err)
	}
}

func handleReadInbox(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	agent := r.URL.Query().Get("agent")
	if agent == "" {
		http.Error(w, "Missing required 'agent' query parameter", http.StatusBadRequest)
		return
	}

	clearStr := r.URL.Query().Get("clear")
	clear := true
	if clearStr == "false" {
		clear = false
	}

	messages, err := client.ReadInbox(r.Context(), agent, clear)
	if err != nil {
		log.Printf("ReadInbox error: %v", err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	payload := struct {
		Messages []tracker.Message `json:"messages"`
	}{
		Messages: messages,
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		log.Printf("JSON encode error: %v", err)
	}
}

type sendMessageRequest struct {
	Sender  string `json:"sender"`
	Target  string `json:"target"`
	Message string `json:"message"`
}

func handleSendMessage(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	var req sendMessageRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Malformed JSON body: "+err.Error(), http.StatusBadRequest)
		return
	}

	if req.Message == "" {
		http.Error(w, "Missing required parameter: 'message' cannot be empty", http.StatusBadRequest)
		return
	}
	if req.Target == "" {
		http.Error(w, "Missing required parameter: 'target' cannot be empty", http.StatusBadRequest)
		return
	}

	err := client.SendMessage(r.Context(), req.Sender, req.Target, req.Message)
	if err != nil {
		log.Printf("SendMessage error: %v", err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"success":true}`))
}

// EventBroker manages a set of active SSE HTTP response channels
type EventBroker struct {
	clients  map[chan string]bool
	entering chan chan string
	leaving  chan chan string
	messages chan string
}

// NewEventBroker initializes a thread-safe EventBroker instance
func NewEventBroker() *EventBroker {
	return &EventBroker{
		clients:  make(map[chan string]bool),
		entering: make(chan chan string),
		leaving:  make(chan chan string),
		messages: make(chan string),
	}
}

// Start dispatches incoming messages to active channels in background loops
func (b *EventBroker) Start() {
	for {
		select {
		case ch := <-b.entering:
			b.clients[ch] = true
		case ch := <-b.leaving:
			delete(b.clients, ch)
			close(ch)
		case msg := <-b.messages:
			for ch := range b.clients {
				select {
				case ch <- msg:
				default:
					// Skip slow clients to prevent buffer blocks
				}
			}
		}
	}
}

// pollTrackerEvents long-polls events from agent-tracker socket and broadcasts to clients
func pollTrackerEvents(b *EventBroker) {
	ctx := context.Background()
	var since int64 = 0

	for {
		res, err := client.WaitEvents(ctx, since)
		if err != nil {
			log.Printf("WaitEvents socket error: %v. Retrying in 5s...", err)
			time.Sleep(5 * time.Second)
			continue
		}

		since = res.LastSeq

		for _, ev := range res.Events {
			evJSON, err := json.Marshal(ev)
			if err == nil {
				b.messages <- string(evJSON)
			}
		}
	}
}

// handleEvents streams Server-Sent Events (SSE) to browser clients
func handleEvents(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	// Set SSE protocol headers
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")

	// Register buffer channel in the broker
	ch := make(chan string, 10)
	broker.entering <- ch

	defer func() {
		broker.leaving <- ch
	}()

	// Flush events down the HTTP connection stream
	for {
		select {
		case msg := <-ch:
			_, _ = fmt.Fprintf(w, "data: %s\n\n", msg)
			if flusher, ok := w.(http.Flusher); ok {
				flusher.Flush()
			}
		case <-r.Context().Done():
			return
		}
	}
}

// handleIndex serves our Warp-skinned HTML/CSS/JS frontend client
func handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write([]byte(indexHTML))
}

// handleRegistryProxy forwards API queries directly to agent-registry service
func handleRegistryProxy(w http.ResponseWriter, r *http.Request) {
	registryProxy.ServeHTTP(w, r)
}
