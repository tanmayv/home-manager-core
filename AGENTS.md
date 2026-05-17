# AI Agents & Skills Guidelines


## Setup & Installation

To enable the AI Agent ecosystem in your Home Manager configuration, follow these steps:

### 1. Bootstrap Your Configuration
If you are setting this up for the first time, you can bootstrap your configuration by cloning this repository and using the provided flake template:

1. **Clone the Repository**:
   ```bash
   git clone sso://user/tanmayvijay/home-manager-minimal-ai ~/minimal-cloudtop
   ```

2. **Initialize Home Manager Config**:
   Create the default Home Manager directory and copy the template files:
   ```bash
   mkdir -p ~/.config/home-manager
   cp -r ~/minimal-cloudtop/flake-template/* ~/.config/home-manager/
   ```

3. **Configure Your Username/LDAP**:
   Open `~/.config/home-manager/flake.nix` and replace `"your-username"` with your actual LDAP/username (lines 51-52):
   ```nix
   home.username = "your-ldap";
   home.homeDirectory = "/usr/local/google/home/your-ldap";
   ```
   Also edit `~/.config/home-manager/setup.nix` to set `username = "your-ldap";`.

4. **Initial Build**:
   Apply the configuration for the first time:
   ```bash
   nix run home-manager -- switch -b backup --flake "~/.config/home-manager#cloudtop"
   ```

### 2. Configure AI Agent Features
Once bootstrapped, you can customize and enable the AI Agent features in `~/.config/home-manager/setup.nix`:

1. **Enable AI Workflow**: In your `setup.nix` file, ensure the `enable-ai-workflow` flag is set to `true`:
   ```nix
   enable-ai-workflow = true;
   ```

2. **Configure AI Features**: You can selectively enable specific AI capabilities within the `ai_features` block in `setup.nix`:
   ```nix
   ai_features = {
     enable_agent_knowledge = true;        # Enables persistent markdown knowledge base in ~/agent_knowledge
     enable_ai_ssa_creator_skill = true;   # Enables skill creator agent
     enable_tmux_based_agent_comms = true; # Enables inter-agent communication (inbox, wrapper scripts)
   };
   ```

3. **Enable Agent Tracker**: The Agent Tracker daemon monitors active agents across sessions and updates your tmux status bar.
   * In `setup.nix`, ensure the tracker is enabled:
     ```nix
     enable-agent-tracker = true;
     ```
   * The tracker runs as a systemd user service (`agent-tracker.service`) and starts automatically upon successful build.

4. **Rebuild**: Apply the changes by running:
   ```bash
   build-and-switch
   ```

---

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

## 5. VM-Based Testing
If the reusable local test VM project exists at `~/projects/nix/test-vm`, agents may use it for NixOS testing when appropriate instead of applying risky system changes directly on the host machine.

- **Condition**: Only use this workflow if `~/projects/nix/test-vm` exists.
- **Preferred Use**: Use it for NixOS module/service validation, remote `nixos-rebuild test`, closure pushing, and SSH/journal inspection.
- **Safety Preference**: Prefer `nixos-rebuild test` before `switch` when targeting the VM.
- **Scope**: Keep host changes minimal; use the VM especially for changes that could disrupt local services, SSH, or agent workflows.
- **Shared Resource**: Treat the VM as a reusable shared environment; avoid casually breaking SSH access, the `dev` user, or the base VM behavior.
- **Instructions**: Follow `~/projects/nix/test-vm/AGENTS.md` for the exact workflow and safety guidance.
