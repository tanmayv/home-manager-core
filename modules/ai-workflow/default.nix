{ pkgs, userSettings, ... }:

let
  inherit (pkgs) lib;
  aiFeatures = userSettings.ai_features or {
    enable_ai_ssa_creator_skill = false;
    enable_tmux_based_agent_comms = false;
  };
in
{
  home.file = {
    ".gemini/GEMINI.md".source = ./dotfiles/GEMINI.md;
    
    ".gemini/agents/.keep".text = "";
    ".gemini/skills/.keep".text = "";
    "${lib.removePrefix "~/" userSettings.local_agent_knowledge_dir}/.keep".text = "";

    ".gemini/mcp_config.json".source = ./dotfiles/mcp_config.json;

    # Link directories
    ".gemini/skills/test-skill".source = ./dotfiles/skills/test-skill;
    ".gemini/agents/home-manager".source = ./dotfiles/agents/home-manager;
    
    # Link hooks
    ".gemini/hooks.json".source = ./dotfiles/hooks/hooks.json;
    ".gemini/hooks".source = ./dotfiles/hooks;

  } // (if aiFeatures.enable_ai_ssa_creator_skill then {
    ".gemini/skills/ai-ssa-creator".source = ./dotfiles/skills/ai-ssa-creator;
  } else { }) // (if aiFeatures.enable_tmux_based_agent_comms then {
    ".gemini/skills/tmux-send-messages-to-agent".source = ./dotfiles/skills/tmux-send-messages-to-agent;
  } else { });
}
