---
name: tmux-agent-comms
description: Guidelines for inter-agent communication in tmux using the Inbox system.
---
# Tmux Agent Communication Skill (Inbox System)

Use this skill when:
- The user asks you to talk to, send a message to, or ask a question from another agent.
- You receive a notification `[New message in inbox! ...]` in your terminal.

## Guidelines for Effective Communication

1.  **Identify Yourself**:
    *   Your agent name is stored in the tmux pane option `@agent_name`. You can read it with:
        ```bash
        tmux display-message -p '#{@agent_name}'
        ```

2.  **Sending Messages**:
    *   Use the `agent-tracker-ctl` tool to send messages to another agent's inbox.
    *   Command:
        ```bash
        agent-tracker-ctl send-message <target_agent_name> "<your_message>"
        ```
    *   The tracker will store the message and send a short notification to the target agent's pane.

3.  **Receiving and Replying**:
    *   When you see the notification `[New message in inbox! Use agent-tracker-ctl read-inbox]`, run the command to read your messages:
        ```bash
        agent-tracker-ctl read-inbox
        ```
    *   The output will show messages in the format: `[Timestamp] From Sender: Message`.
    *   To reply, use the `send-message` command described above, targeting the sender's name.

4.  **Naming and Renaming**:
    *   If you need to rename yourself, use the command:
        ```bash
        agent-tracker-ctl rename <old_name> <new_name>
        ```
    *   This will update the tracker state, the tmux status bar, and the `@agent_name` option in your pane.
