---
name: tmux-agent-comms
description: Guidelines for inter-agent communication in tmux using the Inbox system.
---
# Tmux Agent Communication Skill (Inbox System)

Use this skill when:
- The user asks you to talk to, send a message to, or ask a question from another agent.
- You receive a notification `[New message in inbox from <sender_name>]` in your terminal.

## Guidelines for Effective Communication

1.  **Identify Yourself**:
    *   To find your current name, UUID, PID, and Pane ID, use:
        ```bash
        agent-tracker-ctl whoami
        ```

2.  **Discovering Other Agents**:
    *   To see all active agents and their details, use:
        ```bash
        agent-tracker-ctl list
        ```
    *   This returns a JSON object. Your own entry will be marked with `"is_this_me": true`.

3.  **Sending Messages**:
    *   Send a message to another agent's inbox:
        ```bash
        agent-tracker-ctl send-message <target_agent_name> "<your_message>"
        ```
    *   The tracker will store the message and notify the target agent when they are idle.

4.  **Receiving and Replying**:
    *   When notified, read your messages with:
        ```bash
        agent-tracker-ctl read-inbox
        ```
    *   To reply, use the `send-message` command targeting the `<sender_name>` from the message.

5.  **Renaming**:
    *   To change your own name:
        ```bash
        agent-tracker-ctl rename <new_name>
        ```
    *   This automatically updates the tracker, tmux status bar, and your pane title.
    *   Note: Renaming *other* agents requires `--force` and the old name: `agent-tracker-ctl rename --force <old_name> <new_name>`.
