# AI Agents & Skills Guidelines

This repository relies on a robust architecture of independent, interactable AI agents and modular skills. When contributing to or interacting with this ecosystem, adhere to the following principles:

## 1. The Independent Agent Model
Unlike traditional AI workflows that use hidden sub-agents, this configuration treats agents as independent peers.
- **Visibility**: Agents should execute their tasks in visible tmux panes, allowing the user to monitor progress and intervene if necessary.
- **Communication**: Agents communicate across sessions using the established inter-agent protocol (`send-message-to-agent`, `waiting`, `iamdone`).
- **Identity**: Agents MUST announce their identity in their tmux pane border using the custom `@agent_name` option (`tmux set-option -p @agent_name "YourName"`). This enables other agents to reliably discover and target them.

## 2. Managing Configuration Options
All user-facing feature toggles and settings are centralized in `setup.nix`.
- **Modularity**: If an agent creates a new feature or skill, it should be wrapped in an appropriate `enable_` flag within the `ai_features` block of `setup.nix`.
- **Documentation Obligation**: **CRITICAL:** Whenever a new configuration flag or core setting is added to `setup.nix`, the agent MUST update `docs/Customization.md` to document the new flag, its default state, and its behavior when toggled `true` or `false`.

## 3. Agent Knowledge Base
Agents have access to a persistent, user-visible knowledge base located at `~/agent_knowledge` (configurable via `local_agent_knowledge_dir` in `setup.nix`).
- **User Control**: Agents should not modify or create notes autonomously without prompting or explicit instruction from the user.
- **Format**: All knowledge notes must be in standard Markdown (`.md`) format.

## 4. Agent vs. Skill
When extending capabilities, always prefer creating a **Skill** first. Only create a full **Agent** if the task requires:
- High autonomy and long-running, complex state management.
- Specialized, agent-specific configuration (`agent.json`, `config.yaml`).
- Orchestration of multiple other skills or peer agents.
