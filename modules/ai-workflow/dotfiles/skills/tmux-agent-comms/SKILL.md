---
name: tmux-agent-comms
description: Guidelines for inter-agent communication in tmux.
---
# Tmux Agent Communication Skill

Use this skill when:
- The user gives you a new name or asks you to rename yourself.
- The user asks you to talk to, send a message to, or ask a question from another agent.
- You receive a message in the format `From: <agent-name> | <message>`.

## Guidelines for Effective Communication

1.  **Identify Yourself**:
    *   Before sending a message for the first time, you **MUST** read your name by running:
        ```bash
        tmux display-message -p '#{@agent_name}'
        ```
    *   Use this name in the `From:` field of your message.

2.  **Message Format**:
    *   Always format your outgoing messages as:
        `From: <your_agent_name> | <your_message>`

3.  **Sending Messages**:
    *   Use the `send-message-to-agent` tool to send the message to the target agent.
    *   Target can be a pane ID (e.g., `%10`), a tmux index (e.g., `0:1.0`), or an agent name.

4.  **Replying**:
    *   **CRITICAL**: When you receive a message in the `From: <agent-name> | <message>` format, you **MUST** reply to that agent using the `send-message-to-agent` tool instead of writing your reply to standard output (stdout). This ensures the conversation stays within the agent network.

5.  **Naming Conflicts**:
    *   If you are asked to rename yourself, check that the new name does not conflict with any existing active agent or subagent in the environment.
