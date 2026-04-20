# Gemini AI Workflow

This configuration provides a specialized environment for AI agents to operate efficiently.

## Agent Naming & Identification

To facilitate multi-agent workflows, common AI CLI tools (`jetski-cli`, `gemini-cli`) are wrapped to assign them unique, workspace-aware names.

- **Naming Convention**: `<workspace>-agent-<number>` (e.g., `nixcloud-agent-1`, `local-agent-2`).
- **Workspace Awareness**: The name automatically prefixes the current CitC/Fig workspace name. If not in a workspace, `local` is used.
- **Incremental Numbering**: Each new agent instance in the same tmux session is assigned the next available number.
- **Visual Feedback**: The assigned name is displayed in the tmux **pane title** (border) for easy identification across windows and sessions.
- **Custom Naming**: If the user gives you a specific role (e.g., "You are the Notes Agent"), you MUST update your identity in the tmux environment using the following command:
  ```bash
  tmux set-option -p @agent_name "Notes-Agent"
  ```
  This ensures your new role is visible to the user in the pane title.

## Inter-Agent Communication

Agents MUST communicate across panes and sessions using the following protocols. **IMPORTANT**: You MUST always prefix your message with `From: <your_agent_name> | ` so the receiving agent knows who to respond to.

- `send-message-to-agent <target_pane> "From: <your_name> | <message>"`: Sends a locked message to another agent.
- `waiting <UUID>`: Polls for a response from another agent.
- `iamdone <UUID> "message"`: Responds to a request.

Example:
```bash
send-message-to-agent "%10" "From: minimal-cloudtop-agent-1 | What is the status of ZV2?"
```

See `modules/scripts/` for implementation details of these tools.
