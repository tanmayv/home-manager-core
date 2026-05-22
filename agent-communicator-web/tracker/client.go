package tracker

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"
)

// jsonRPCRequest represents JSON-RPC 2.0 request payload
type jsonRPCRequest struct {
	JSONRPC string `json:"jsonrpc"`
	Method  string `json:"method"`
	Params  any    `json:"params,omitempty"`
	ID      int    `json:"id"`
}

// jsonRPCResponse represents JSON-RPC 2.0 response payload
type jsonRPCResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *jsonRPCError   `json:"error,omitempty"`
	ID      int             `json:"id"`
}

// jsonRPCError represents JSON-RPC 2.0 error detail
type jsonRPCError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    any    `json:"data,omitempty"`
}

func (e *jsonRPCError) Error() string {
	return fmt.Sprintf("RPC error (%d): %s", e.Code, e.Message)
}

// Client represents the connection manager to the agent-tracker JSON-RPC Unix socket
type Client struct {
	SocketPath string
	idSeq      int
}

// NewClient initializes a Client socket instance, auto-resolving socket path if empty
func NewClient(socketPath string) (*Client, error) {
	if socketPath == "" {
		var err error
		socketPath, err = resolveSocketPath()
		if err != nil {
			return nil, err
		}
	}
	return &Client{SocketPath: socketPath}, nil
}

// resolveSocketPath discovers socket path matching standard XDG locations
func resolveSocketPath() (string, error) {
	if path := os.Getenv("AGENT_TRACKER_SOCKET"); path != "" {
		return expandTilde(path)
	}

	cacheDir := os.Getenv("XDG_CACHE_HOME")
	if cacheDir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", fmt.Errorf("failed to discover user home directory: %w", err)
		}
		cacheDir = filepath.Join(home, ".cache")
	}

	path := filepath.Join(cacheDir, "agent-tracker", "agent-tracker.sock")
	return expandTilde(path)
}

func expandTilde(path string) (string, error) {
	if !strings.HasPrefix(path, "~") {
		return path, nil
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(home, path[1:]), nil
}

// call dispatches a synchronous single-transaction RPC query over a Unix domain socket connection
func (c *Client) call(ctx context.Context, method string, params any, out any) error {
	c.idSeq++
	reqID := c.idSeq

	req := jsonRPCRequest{
		JSONRPC: "2.0",
		Method:  method,
		Params:  params,
		ID:      reqID,
	}

	var d net.Dialer
	conn, err := d.DialContext(ctx, "unix", c.SocketPath)
	if err != nil {
		return fmt.Errorf("failed to connect to tracker socket %s: %w", c.SocketPath, err)
	}
	defer conn.Close()

	if err := json.NewEncoder(conn).Encode(req); err != nil {
		return fmt.Errorf("failed to encode RPC request: %w", err)
	}

	var resp jsonRPCResponse
	if err := json.NewDecoder(conn).Decode(&resp); err != nil {
		return fmt.Errorf("failed to decode RPC response: %w", err)
	}

	if resp.Error != nil {
		return resp.Error
	}

	if resp.ID != reqID {
		return fmt.Errorf("RPC response ID mismatch: got %d, expected %d", resp.ID, reqID)
	}

	if out != nil {
		if err := json.Unmarshal(resp.Result, out); err != nil {
			return fmt.Errorf("failed to parse RPC result: %w", err)
		}
	}

	return nil
}

// List queries active registered agent registry structures
func (c *Client) List(ctx context.Context) (map[string]Agent, error) {
	var res map[string]Agent
	if err := c.call(ctx, "list", nil, &res); err != nil {
		return nil, err
	}
	return res, nil
}

// ReadInbox reads direct messages from the target agent inbox queue
func (c *Client) ReadInbox(ctx context.Context, agentName string, clear bool) ([]Message, error) {
	params := struct {
		AgentName string `json:"agent_name"`
		Clear     bool   `json:"clear"`
	}{
		AgentName: agentName,
		Clear:     clear,
	}
	var res ReadInboxResult
	if err := c.call(ctx, "get_inbox", params, &res); err != nil {
		return nil, err
	}
	return res.Messages, nil
}

// SendMessage dispatches a direct message payload targeting remote agents
func (c *Client) SendMessage(ctx context.Context, senderName, target, body string) error {
	params := map[string]any{
		"message": body,
	}
	if senderName != "" {
		params["sender_name"] = senderName
	}

	// Resolve target addresses dynamically
	if strings.Contains(target, "/") {
		params["target_address"] = target
	} else if isUUID(target) {
		params["target_address"] = "local/" + target
	} else {
		params["agent_name"] = target
	}

	return c.call(ctx, "send_message", params, nil)
}

func isUUID(value string) bool {
	if len(value) != 36 {
		return false
	}
	for i, r := range value {
		switch i {
		case 8, 13, 18, 23:
			if r != '-' {
				return false
			}
		default:
			if !(r >= '0' && r <= '9') && !(r >= 'a' && r <= 'f') && !(r >= 'A' && r <= 'F') {
				return false
			}
		}
	}
	return true
}

// WaitEvents registers long-polling stream handlers waiting for broker notifications
func (c *Client) WaitEvents(ctx context.Context, since int64) (WaitEventsResult, error) {
	params := struct {
		Since int64 `json:"since"`
	}{
		Since: since,
	}
	var res WaitEventsResult
	if err := c.call(ctx, "wait_events", params, &res); err != nil {
		return WaitEventsResult{}, err
	}
	return res, nil
}
