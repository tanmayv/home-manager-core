package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"sort"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

var agentListProvider = loadAgentsFromCtl

type ctlAgent struct {
	Name          string   `json:"name"`
	Aliases       []string `json:"aliases"`
	AgentID       string   `json:"agent_id"`
	Scope         string   `json:"scope"`
	Status        string   `json:"status"`
	CWD           string   `json:"cwd"`
	Hostname      string   `json:"hostname"`
	TargetAddress string   `json:"target_address"`
	TmuxPane      string   `json:"tmux_pane"`
}

func loadAgents(_ localClient, _ remoteClient) tea.Cmd {
	return func() tea.Msg {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		rows, err := agentListProvider(ctx)
		return agentsLoaded{Rows: rows, Err: err}
	}
}

func loadAgentsFromCtl(ctx context.Context) ([]agentRow, error) {
	out, err := exec.CommandContext(ctx, "agent-tracker-ctl", "list").Output()
	if err != nil {
		return nil, fmt.Errorf("agent-tracker-ctl list: %w", err)
	}
	var agents map[string]ctlAgent
	if err := json.Unmarshal(out, &agents); err != nil {
		return nil, fmt.Errorf("decode agent-tracker-ctl list: %w", err)
	}
	rows := make([]agentRow, 0, len(agents))
	for key, agent := range agents {
		rows = append(rows, rowFromCtlAgent(key, agent))
	}
	sort.Slice(rows, func(i, j int) bool {
		if rows[i].Scope != rows[j].Scope {
			return rows[i].Scope < rows[j].Scope
		}
		return rows[i].Name < rows[j].Name
	})
	return rows, nil
}

func rowFromCtlAgent(key string, agent ctlAgent) agentRow {
	scope := fallback(agent.Scope, "local")
	target := fallback(agent.TargetAddress, key)
	if scope != "remote" {
		return agentRow{Name: key, TargetAddress: target, AgentName: key, Scope: "local", Status: agent.Status, CWD: fallback(agent.CWD, "unknown"), TmuxPane: agent.TmuxPane}
	}
	host, name := splitRemoteTarget(target)
	if agent.Hostname != "" {
		host = agent.Hostname
	}
	if name == "" {
		name = fallback(agent.Name, key)
	}
	return agentRow{Name: remoteDisplayName(target, host, name), TargetAddress: target, Hostname: host, AgentName: name, Scope: "remote", Status: agent.Status, CWD: fallback(agent.CWD, "unavailable"), TmuxPane: agent.TmuxPane}
}

func splitRemoteTarget(target string) (string, string) {
	if strings.Contains(target, ":") {
		target = strings.SplitN(target, ":", 2)[1]
	}
	parts := strings.SplitN(target, "/", 2)
	if len(parts) != 2 {
		return "", target
	}
	return parts[0], parts[1]
}

func remoteDisplayName(target, host, name string) string {
	prefix := ""
	if strings.Contains(target, ":") {
		prefix = strings.SplitN(target, ":", 2)[0] + ":"
	}
	return prefix + shortHost(host) + "/" + name
}
