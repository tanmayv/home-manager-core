# Minimal Cloudtop Home Manager Config

This repository provides a modern, AI-focused Home Manager configuration tailored for Googlers setting up a new Cloudtop. It bridges the gap between powerful CLI tools and an accessible, interactive terminal interface.

## Motivation & Philosophy

### Why the CLI for AI?
The Command Line Interface (CLI) is the most natural environment for software engineering. Unlike GUI-based AI chats, a CLI agent has direct access to your local files, build tools, and system state. This "closeness to the metal" allows for a seamless loop of **Plan -> Act -> Validate**, where the agent can run tests, grep codebases, and fix bugs in the same context where you work.

### The Power of Tmux
Tmux is more than just a terminal multiplexer; it's the glue that holds this environment together. By leveraging Tmux, we create a persistent workspace that survived disconnects and enables:
- **Spatial AI interaction**: Running an agent in one pane while you code in another.
- **Inter-Agent Communication**: Allowing agents to "talk" to each other across panes using standardized protocols.
- **Visual Context**: Using pane borders and titles to identify active agents and their status.

## Key Solving: The Workspace Challenge

A major pain point for Googlers is navigating between multiple CitC/Fig workspaces and keeping track of related terminal sessions. This configuration solves this through **Workspace-Session Parity**:

1.  **Automatic Session Management**: Each Fig workspace is treated as its own Tmux session. When you switch workspaces, you switch sessions, keeping your history, panes, and buffers isolated and organized.
2.  **Smart Navigation Tools**:
    *   **Zoxide**: Our `cd` wrapper is workspace-aware. If you jump to a directory that exists in a different workspace, it automatically normalizes the path to your *current* workspace root, preventing accidental cross-workspace edits.
    *   **hgd Integration**: Running `hgd` to switch or create a workspace automatically triggers a Tmux session switch, ensuring your terminal environment always matches your current CitC context.

## Accessibility & Discovery

While we use powerful CLI tools, we believe they shouldn't require an encyclopedia of keybindings.
- **Mouse Interactivity**: Clickable session lists and right-click menus in the status bar make session management intuitive for everyone.
- **Command Palette (`Ctrl+p`)**: A searchable hub for all workflows, from managing windows to triggering AI skills, ensuring features are discoverable without memorizing shortcuts.

## AI Agent Ecosystem

This configuration acts as a hub for AI capabilities that can be selectively enabled in `setup.nix`:

### Inter-Agent Communication vs. Sub-Agents
Traditional AI workflows use "sub-agents"—child processes managed entirely by a primary agent. Our model is different: **Independent, Interactable Agents**.
- **User Visibility**: Agents run in their own visible Tmux panes. You can see what they are doing, intervene, or take over at any time.
- **Cross-Session Chat**: Using our inter-agent protocol (`send-message-to-agent`), an agent in one session can query an agent in another. They are peers, not just hidden sub-processes.

### Persistent Knowledge
We support a **User-Visible Knowledge Base** (markdown notes in `~/agent_knowledge`). Unlike hidden "agent memory," these notes are for you. Agents only update or reference them when prompted, ensuring you stay in control of the information they store.

## Installation & Setup

Please refer to [docs/GettingStarted.md](docs/GettingStarted.md) for detailed installation instructions.

## Customization

To learn how to personalize your configuration and toggle features in `setup.nix`, please read the [Customization Guide](docs/Customization.md).

## Key Features (Technical List)

*   **Intelligent Navigation**: Fig/CitC aware `cd` and `hgd` wrappers.
*   **Mouse-Centric Tmux**: Clickable status bar, context menus, and smart pane switching (`Ctrl+h/j/k/l`).
*   **Command Palette**: LRU-ranked search for system and AI commands.
*   **AI Orchestration**: Protocol tools (`iamdone`, `waiting`, `send-message-to-agent`) for multi-agent workflows.
*   **Agent Knowledge**: Dedicated directory for persistent markdown notes.
*   **Tokyo Night Theme**: Unified high-contrast aesthetic across all tools.

## Terminals

| Terminal | Supported |
| :--- | :--- |
| Ghostty | ✅ |
| Kitty | ✅ |

