# Gemini AI Workflow

This configuration provides a specialized environment for AI agents to operate efficiently.

## Agent Naming & Identification

To facilitate multi-agent workflows, common AI CLI tools (`jetski-cli`, `gemini-cli`) are wrapped using the `agent-wrapper` script to assign them unique, workspace-aware names.

### How `agent-wrapper` Works:
1. **Workspace Detection**: It looks at your current directory (`$PWD`). If you are in a CitC/Fig workspace (`/google/src/cloud/$USER/WORKSPACE/...`), it extracts the workspace name. Otherwise, it defaults to `local`.
2. **Identity Assignment**: It scans all active panes in the *current tmux session* for existing `@agent_name` values.
3. **Unique Numbering**: It assigns the next available number for that workspace, e.g., `nixcloud-agent-1`, then `nixcloud-agent-2`.
4. **Environment Integration**:
   - Sets the tmux pane option `@agent_name`.
   - Sets the tmux **pane title** to the agent name.
   - Refreshes the tmux status bar to reflect the new agent.
5. **Cleanup**: When the agent process exits, it automatically clears the identity and refreshes the status bar.

- **Custom Naming**: If the user gives you a specific role (e.g., "You are the Notes Agent"), you MUST update your identity in the tmux environment using the following command:
  ```bash
  tmux set-option -p @agent_name "Notes-Agent"
  ```

## Inter-Agent Communication

Agents MUST communicate across panes and sessions using the following protocols. 

**IMPORTANT**: When you receive a message in the format `From: <sender_name> | <message>`, you MUST use `send-message-to-agent` to reply back to the sender instead of printing to stdout. This ensures the conversation stays within the correct panes.

- `send-message-to-agent <target> "From: <your_name> | <message>"`: 
  - **Target**: Can be a pane ID (e.g. `%10`), a tmux index (e.g. `0:1.0`), or an **agent name** (e.g. `Notes-Agent`).
- `waiting <UUID>`: Polls for a response from another agent.
- `iamdone <UUID> "message"`: Responds to a request.

### Example Protocol:
1. **Agent A** (`nixcloud-agent-1`):
   ```bash
   send-message-to-agent "Notes-Agent" "From: nixcloud-agent-1 | What is the status of ZV2?"
   ```
2. **Notes-Agent** sees the input and replies:
   ```bash
   send-message-to-agent "nixcloud-agent-1" "From: Notes-Agent | ZV2 investigation is in progress..."
   ```

See `modules/scripts/` for implementation details of these tools.
