---
name: tmux-send-messages-to-agent
description: Skill for inter-agent communication using tmux and CLI scripts.
---

# Tmux Agent Communication Skill

This skill enables agents to communicate with each other across different tmux panes or windows.

## Core Tools
- `send-message-to-agent <target> <message>`: Use this for back-and-forth communication between agents.
- `waiting`: Use this to wait for a signal/message from another agent. It returns a UUID.
- `iamdone <UUID> [message]`: Use this to send the final output/signal to an agent that is currently `waiting`.

## Workflow & Rules
1. **Naming**: If you don't have a name yet, you MUST ask the user for one. You can suggest a name based on the current context (e.g., "CodebaseAnalyst", "TestFixer"), but confirm it with the user.
2. **Identity**: Once named, set your agent name using the custom tmux option `@agent_name`. This will be displayed in the pane border alongside your Pane ID and original Title:
   `tmux set-option -p @agent_name "<name>"`
   If your pane is the only one in the window, also change the window title to reflect that an agent is active:
   `tmux rename-window "Agent:<name>"`
3. **Message Format**: Every message sent via `send-message-to-agent` MUST follow this format:
   `From: <your-agent-name> | <message-content>`
4. **Large Payloads**: If a response or message is long (e.g., code snippets, long reports), prefer writing the content to a temporary file in `/tmp/` and sending the file path instead.
5. **Targeting**: To find other agents to communicate with, query tmux panes across all sessions. Note that the Pane ID (e.g., `%4`) is displayed in the pane border for easy targeting:
   `tmux list-panes -a -F "#{pane_id} #{@agent_name} #{pane_title} #{window_name}"`
   Look for panes where `@agent_name` is set.
6. **Protocol**:
   - Use `send-message-to-agent` for conversational back-and-forth.
   - Use `waiting` when you expect a final result or need to pause execution until another agent completes a task.
   - Use `iamdone` to deliver that final result to the waiting agent using the UUID they provided.
   - **Crucial**: When asking another agent to signal completion on a UUID, always explicitly instruct them to "pass the message when calling `iamdone <uuid> <message>`" to ensure the payload is delivered.

## Example
1. Agent A calls `waiting` and gets `UUID_123`.
2. Agent A sends a message to Agent B: `send-message-to-agent %4 "From: AgentA | Please fix the tests in src/ and signal me on UUID_123 (pass the message when calling iamdone <uuid> <message>)"`
3. Agent B performs the task.
4. Agent B signals completion: `iamdone UUID_123 "Tests are fixed. See /tmp/test_report.txt"`
5. Agent A's `waiting` call finishes and receives the report path.
