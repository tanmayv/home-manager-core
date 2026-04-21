---
name: extract-agent
description: Extract a custom agent from the conversation or a description.
---
# Extract Agent Skill

Use this skill when:
- The user asks you to extract an agent from the current conversation.
- The user provides a description of an agent and asks you to create it.

## Instructions

1.  **Analyze Context**:
    *   If the user provides an agent description, use that.
    *   If not, analyze the conversation to identify a specialized persona, set of instructions, or tool usage patterns that could be extracted as a reusable custom agent.
2.  **Create Plan**:
    *   Draft an Implementation Plan for the new agent, including:
        *   Suggested agent name.
        *   Role and goals.
        *   System prompt content (broken into sections if needed).
        *   Required tools.
3.  **Review**:
    *   Present this plan to the user and request feedback.
4.  **Persist (Generate Both Formats)**:
    *   **CRITICAL**: Do not write to disk yet. Wait for explicit user approval.
    *   Once approved, generate both of the following:
        *   **For Gemini**: Create a file `~/.gemini/agents/<agent-name>.md` with YAML frontmatter for properties and the system prompt.
        *   **For Jetski**: Create a directory `~/.gemini/jetski/agents/<agent-name>/`.
            *   Write `agent.json` pointing to `config.yaml` (Style 1: Declarative).
            *   Write `config.yaml` defining `custom_agent` with `system_prompt_sections` and `tool_names`.
