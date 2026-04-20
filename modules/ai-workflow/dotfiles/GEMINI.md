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

## Agent Knowledge & Persistence

To maintain persistent memory across sessions, agents have access to a dedicated knowledge directory.

- **Storage Directory**: The directory path is defined in `setup.nix` as `local_agent_knowledge_dir` (e.g., `~/agent_knowledge`).
- **Accessing Knowledge**: You should check this directory for existing markdown notes when the user asks you to "remember" or "look up" information from past interactions.
- **Creating Notes**: Use the command provided by `local_agent_knowledge_create_command` (typically `nn`) to create new persistent notes in your pkm directory, which will then be linked/available for future agents.

## Inter-Agent Communication

Agents MUST communicate across panes and sessions using specialized protocols. Implementation scripts are located in `~/.config/minimal-cloudtop/modules/scripts/`.

### 1. Direct Keyboard Simulation (`send-message-to-agent`)
This tool uses `tmux send-keys` to simulate typing directly into the target pane's input buffer. 

- **Reliability**: The target pane MUST be running a process that actively listens to `stdin` (e.g., a shell prompt or the `waiting` script).
- **Usage**: `send-message-to-agent <target> "From: <your_name> | <message>"`
  - **Target**: Can be a pane ID (e.g. `%10`), a tmux index (e.g. `0:1.0`), or an **agent name** (e.g. `Notes-Agent`).
  - **Identity**: `<your_name>` MUST be the exact value of your `@agent_name` tmux option so the receiver can reply to you.
- **Protocol**: You MUST always use `send-message-to-agent` to reply to messages with a `From:` prefix instead of printing to your own stdout.

### 2. File-Based Signaling (`waiting` & `iamdone`)
For more reliable or asynchronous communication, agents use persistent signals stored in `~/.tmux_signals/`.

- **`waiting <UUID>`**: Blocks and polls for a response file named after the UUID.
- **`iamdone <UUID> "message"`**: Writes the response message to the signal file, unblocking the waiting agent.

### Example Flows:

#### Simple Interactive Reply
1. **Agent A** (`nixcloud-agent-1`):
   ```bash
   send-message-to-agent "Notes-Agent" "From: nixcloud-agent-1 | What is the status of ZV2?"
   ```
2. **Notes-Agent** receives the typed text and replies:
   ```bash
   send-message-to-agent "nixcloud-agent-1" "From: Notes-Agent | ZV2 investigation is in progress..."
   ```

#### Asynchronous Task (File-Based)
1. **Agent A** needs a long-running task done. It generates a UUID (or lets the script generate one) and runs:
   ```bash
   waiting 1234-abcd
   ```
2. **Agent A** sends the request to **Agent B**:
   ```bash
   send-message-to-agent "Agent-B" "From: Agent-A | Please index this directory and reply to UUID 1234-abcd"
   ```
3. **Agent B** completes the indexing, then signals completion:
   ```bash
   iamdone 1234-abcd "Indexing complete. Found 50 files."
   ```
4. **Agent A**'s `waiting` process detects the file, prints the message, and exits, allowing Agent A to continue.
