{ pkgs, userSettings, lib, config, ... }:

let
  username = config.home.username;
  aiFeatures = userSettings.ai_features or {
    enable_ai_ssa_creator_skill = false;
    enable_tmux_based_agent_comms = false;
    enable_agent_knowledge = false;
    enable_home_manager_skill = false;
  };

  geminiMdContent = ''
# Gemini AI Workflow

## Agent Naming & Identification

To facilitate multi-agent workflows, You are assigned a unique-name which other agents can Identify you with.
The name is set as @agent-name tmux option.

'' + lib.optionalString (aiFeatures.enable_agent_knowledge or false) ''

## Agent Knowledge & Persistence

To maintain persistent memory across sessions, agents have access to a dedicated knowledge directory.

- **Storage Directory**: The directory path is defined in `setup.nix` as `local_agent_knowledge_dir` (e.g., `~/agent_knowledge`).
- **Accessing Knowledge**: You should check this directory for existing markdown notes when the user asks you to "remember" or "look up" information from past interactions.
- **Creating Notes**: Use the command provided by `local_agent_knowledge_create_command` (typically `nn`) to create new persistent notes in your pkm directory, which will then be linked/available for future agents.
'' + lib.optionalString (aiFeatures.enable_tmux_based_agent_comms or false) ''

## Inter-Agent Communication
 
 Agents MUST communicate across panes and sessions using specialized protocols.
 
 - **CRITICAL**: Use the `tmux-agent-comms` skill when you are asked to change your name, talk to another agent, send a message, or ask a question to another agent. This skill contains all the necessary steps and guidelines for effective communication.
 - If you receive a message of format `From <agent-name> | <message>` Use `tmux-agent-comms` to reply to the agent.
'';

  # Logic for handling external extensions (Piper or local)
  extraExtensions = userSettings.extra-ai-extensions or [ ];
  personalPiperConfig = "/google/src/files/head/depot/configs/users/${username}/_agents";
  allExtensions = [ personalPiperConfig ] ++ extraExtensions;

  # Format inherits for jetski/skills.json
  # We assume each extension directory has a skills.json
  jetskiSkills = {
    inherits = map (path: { path = "${path}/skills.json"; }) allExtensions;
    entries = [ ];
  };
in
{
  home.file = {
    ".gemini/GEMINI.md".text = geminiMdContent;
    
    ".gemini/agents/.keep".text = "";
    ".gemini/skills/.keep".text = "";
    "${lib.removePrefix "~/" userSettings.local_agent_knowledge_dir}/.keep".text = "";

    ".gemini/jetski/mcp_config.json".source = ./dotfiles/mcp_config.json;
    ".gemini/jetski/skills.json".text = builtins.toJSON jetskiSkills;
    ".gemini/gemini-extension.json".source = ./dotfiles/gemini-extension.json;

    # Link directories
    ".gemini/agents/home-manager".source = ./dotfiles/agents/home-manager;

    ".gemini/skills/extract-skill".source = ./dotfiles/skills/extract-skill;
    ".gemini/skills/extract-agent".source = ./dotfiles/skills/extract-agent;
    
    # Link hooks
    ".gemini/hooks.json".source = ./dotfiles/hooks/hooks.json;
    ".gemini/jetski/hooks.json".source = ./dotfiles/hooks/jetski_hooks.json;
    ".gemini/hooks".source = ./dotfiles/hooks;

  } // (if aiFeatures.enable_ai_ssa_creator_skill then {
    ".gemini/skills/ai-ssa-creator".source = ./dotfiles/skills/ai-ssa-creator;
  } else { }) // (if aiFeatures.enable_tmux_based_agent_comms then {
    ".gemini/skills/tmux-agent-comms".source = ./dotfiles/skills/tmux-agent-comms;
  } else { }) // (if aiFeatures.enable_home_manager_skill then {
    ".gemini/skills/home-manager-skill".source = ./dotfiles/skills/home-manager-skill;
  } else { });

  home.activation.geminiLinkExtensions = lib.hm.dag.entryAfter ["linkGeneration"] ''
    # Link the local configuration directory
    /google/bin/releases/gemini-cli/tools/gemini -- extensions link $HOME/.gemini --consent || true
    
    # Link additional extensions
    ${lib.concatMapStringsSep "\n" (path: ''
      if [[ -d "${path}" ]]; then
        /google/bin/releases/gemini-cli/tools/gemini -- extensions link "${path}" --consent || true
      fi
    '') allExtensions}
  '';
}
