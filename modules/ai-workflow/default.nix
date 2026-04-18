{ pkgs, userSettings, ... }:

let
  inherit (pkgs) lib;
  aiFeatures = userSettings.ai_features or {
    enable_ai_ssa_creator_skill = false;
  };
in
{
  home.file = {
    ".gemini/jetski/GEMINI.md".source = ./dotfiles/GEMINI.md;
    
    ".gemini/jetski/agents/.keep".text = "";
    ".gemini/jetski/skills/.keep".text = "";

    ".gemini/jetski/mcp_config.json".source = ./dotfiles/mcp_config.json;

    # Link directories
    ".gemini/jetski/skills/test-skill".source = ./dotfiles/skills/test-skill;
    ".gemini/jetski/agents/home-manager".source = ./dotfiles/agents/home-manager;
    
    # Link hooks
    ".gemini/jetski/hooks.json".source = ./dotfiles/hooks/hooks.json;
    ".gemini/jetski/hooks".source = ./dotfiles/hooks;

  } // (if aiFeatures.enable_ai_ssa_creator_skill then {
    ".gemini/jetski/skills/ai-ssa-creator".source = ./dotfiles/skills/ai-ssa-creator;
  } else { });
}
