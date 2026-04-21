---
name: extract-skill
description: Extract a skill from the conversation or a description.
---
# Extract Skill

Use this skill when:
- The user asks you to extract a skill from the current conversation.
- The user provides a description of a skill and asks you to create it.

## Instructions

1.  **Analyze Context**:
    *   If the user provides a skill description, use that as the basis.
    *   If not, analyze the recent conversation history to identify successful patterns, instructions, or specialized workflows that could be extracted as a reusable skill.
2.  **Use AI-SSA if Available**:
    *   If the `ai-ssa-creator` skill is available (check `~/.gemini/skills/ai-ssa-creator`), you may use it to help generate or refine the skill definition.
3.  **Create Plan**:
    *   Draft an Implementation Plan for the new skill, including:
        *   Suggested skill name.
        *   Clear description of when to use it.
        *   The core prompt instructions to be placed in `SKILL.md`.
4.  **Review**:
    *   Present this plan to the user and request feedback.
5.  **Persist**:
    *   **CRITICAL**: Do not write the skill to disk yet. Wait for explicit user approval.
    *   Once approved, create a directory `~/.gemini/skills/<skill-name>/` and write the `SKILL.md` file there.
