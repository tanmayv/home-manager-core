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

  # Format inherits for jetski/skills.json
  jetskiSkills = {
    inherits = [ ];
    entries = [ ];
  };
in
{
  home.file = {
    ".gemini/GEMINI.md".text = geminiMdContent;
    
    ".gemini/agents/.keep".text = "";
    ".gemini/skills/.keep".text = "";
    "${lib.removePrefix "~/" userSettings.local_agent_knowledge_dir}/.keep".text = "";

    ".gemini/jetski/skills.json".text = builtins.toJSON jetskiSkills;

    # Link directories
    ".gemini/agents/home-manager".source = ./dotfiles/agents/home-manager;

    ".gemini/skills/extract-skill".source = ./dotfiles/skills/extract-skill;
    ".gemini/skills/extract-agent".source = ./dotfiles/skills/extract-agent;
    
    # Link hooks
    ".gemini/hooks.json".source = ./dotfiles/hooks/hooks.json;
    ".gemini/jetski/hooks.json".source = ./dotfiles/hooks/jetski_hooks.json;
    
    ".gemini/hooks/after_agent.py".source = ./dotfiles/hooks/after_agent.py;
    ".gemini/hooks/jetski_post_tool.py".source = ./dotfiles/hooks/jetski_post_tool.py;
    ".gemini/hooks/jetski_pre_tool.py".source = ./dotfiles/hooks/jetski_pre_tool.py;
    ".gemini/hooks/notify_approval.py".source = ./dotfiles/hooks/notify_approval.py;
    ".gemini/hooks/post_invocation.py".source = ./dotfiles/hooks/post_invocation.py;
    ".gemini/hooks/post_tool.py".source = ./dotfiles/hooks/post_tool.py;
    ".gemini/hooks/pre_invocation.py".source = ./dotfiles/hooks/pre_invocation.py;
    ".gemini/hooks/pre_tool.py".source = ./dotfiles/hooks/pre_tool.py;
    ".gemini/hooks/session_end.py".source = ./dotfiles/hooks/session_end.py;
    ".gemini/hooks/stop.py".source = ./dotfiles/hooks/stop.py;

  } // (if aiFeatures.enable_ai_ssa_creator_skill then {
    ".gemini/skills/ai-ssa-creator".source = ./dotfiles/skills/ai-ssa-creator;
  } else { }) // (if aiFeatures.enable_tmux_based_agent_comms then {
    ".gemini/skills/tmux-agent-comms".source = ./dotfiles/skills/tmux-agent-comms;
  } else { }) // (if aiFeatures.enable_home_manager_skill then {
    ".gemini/skills/home-manager-skill".source = ./dotfiles/skills/home-manager-skill;
  } else { });

}
