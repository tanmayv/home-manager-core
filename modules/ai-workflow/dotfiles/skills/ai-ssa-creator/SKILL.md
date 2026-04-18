---
name: ai-ssa-creator
description: Creates appropriate Slash commands, Skills, or Agents based on user prompt or extracted knowledge, using doc/guide.md as reference.
---
# AI Slash/Skill/Agent Creator

This skill is triggered when the user asks to create a new capability or when an agent wants to extract knowledge into a new command/skill/agent.

## Instructions

1.  **Analyze Request**: Read the user prompt or the provided knowledge.
2.  **Consult Guide**: Refer to `doc/guide.md` to decide whether a **Slash Command**, **Skill**, or **Agent** is appropriate based on complexity, autonomy, and context.
3.  **Create Entity**:
    *   If **Slash Command**: Create a Skill and describe how to map it or use it as a command.
    *   If **Skill**: Create a new `SKILL.md` file in `~/.gemini/jetski/skills/{skill_name}/` with appropriate YAML frontmatter and instructions.
    *   If **Agent**: Create a new directory in `~/.gemini/jetski/agents/{agent_name}/` with an `agent.json` file and optionally a `config.yaml` or `GEMINI.md`.
4.  **Nix Integration**: Remind the user that to make it persistent, it should be added to the Home Manager configuration (e.g., `modules/ai-workflow.nix`).

## Golden Rule
Start with a Skill unless a Slash Command or Agent is clearly more appropriate as per the guide.
