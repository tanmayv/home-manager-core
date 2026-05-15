---
name: tmux-agent-comms
description: Guidelines for inter-agent communication in tmux using the Agent Tracker Inbox system.
---
# Tmux Agent Communication Skill (Inbox System)

Use this skill when:
- The user asks you to talk to, send a message to, or ask a question from another agent.
- You receive a notification `[New message in inbox from <sender_name>]` in your terminal.

## Guidelines for Effective Communication

1.  **Identify Yourself**:
    *   To find your current Name, stable Agent ID, PID, and Pane ID, use:
        ```bash
        agent-tracker-ctl whoami
        ```
    *   Your `Agent ID` is your absolute, immutable identifier across tracker restarts and renames.

2.  **Discovering Other Agents**:
    *   To see all active agents and their details, use:
        ```bash
        agent-tracker-ctl list
        ```
    *   This returns a JSON object keyed by current display names. Your own entry will be marked with `"is_this_me": true`. Each entry also lists its stable `"agent_id"` and historical `"aliases"`.

3.  **Sending Messages**:
    *   Send a message to another agent's inbox by display name:
        ```bash
        agent-tracker-ctl send-message <target_agent_name> "<your_message>"
        ```
    *   Or target an agent unambiguously by its stable Agent ID:
        ```bash
        agent-tracker-ctl send-message --id <target_agent_id> "<your_message>"
        ```
    *   **Alias Resolution**: If you send a message to an old name (alias) of an agent that was renamed, the tracker will successfully deliver it to the new name and output a warning: `Note: Agent '<old_name>' was renamed to '<current_name>'.` You should note this correction for future communication.

4.  **Receiving and Replying**:
    *   When notified of a new message, read your inbox. Use `--clear` to acknowledge and archive unread messages, or `--last N` to inspect recent history:
        ```bash
        agent-tracker-ctl read-inbox --clear
        ```
    *   To reply, use `send-message` targeting the `<sender_name>` (or `--id <sender_id>` if known) from the message payload.

5.  **Renaming & Focusing**:
    *   To change your own display name:
        ```bash
        agent-tracker-ctl rename <new_name>
        ```
    *   Renaming *other* agents requires `--force` and the old name: `agent-tracker-ctl rename --force <old_name> <new_name>`.
    *   To focus an agent's tmux pane in the terminal:
        ```bash
        agent-tracker-ctl focus <target_agent_name>
        ```
        *(Or use `agent-tracker-ctl focus --id <target_agent_id>`)*.
