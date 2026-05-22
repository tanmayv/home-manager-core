package tracker

// Agent represents tracked agent information from agent-tracker
type Agent struct {
	Name          string   `json:"name"`
	AgentID       string   `json:"agent_id"`
	UUID          string   `json:"uuid"`
	Status        string   `json:"status"`
	AgentType     string   `json:"agent_type"`
	Aliases       []string `json:"aliases"`
	CWD           string   `json:"cwd,omitempty"`
	Scope         string   `json:"scope,omitempty"`
	Hostname      string   `json:"hostname,omitempty"`
	TargetAddress string   `json:"target_address,omitempty"`
}

// Message represents inbox direct messages
type Message struct {
	Sender    string `json:"sender"`
	Timestamp string `json:"timestamp"`
	Body      string `json:"message"`
	Read      bool   `json:"read"`
	MessageID string `json:"message_id,omitempty"`
}

// Event represents event tracking logs
type Event struct {
	Seq             int64   `json:"seq"`
	Type            string  `json:"type"`
	Timestamp       float64 `json:"timestamp"`
	TargetAgentID   string  `json:"target_agent_id,omitempty"`
	TargetAgentName string  `json:"target_agent_name,omitempty"`
	Sender          string  `json:"sender,omitempty"`
	MessageID       string  `json:"message_id,omitempty"`
}

// WaitEventsResult represents long-poll event response
type WaitEventsResult struct {
	Events  []Event `json:"events"`
	LastSeq int64   `json:"last_seq"`
}

// ReadInboxResult represents direct message inbox contents
type ReadInboxResult struct {
	Messages []Message `json:"messages"`
}
