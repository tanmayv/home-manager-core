{ pkgs, ... }:

{
  home.file = {
    ".gemini/jetski/GEMINI.md".text = "# Gemini AI Workflow\n";
    
    ".gemini/jetski/agents/.keep".text = "";
    ".gemini/jetski/skills/.keep".text = "";

    ".gemini/jetski/skills/test-skill/SKILL.md".text = ''
      # Test Skill
      This is a test skill for Jetski.
    '';

    ".gemini/jetski/agents/test-agent/agent.json".text = ''
      {
        "name": "test-agent",
        "description": "A test agent for Jetski"
      }
    '';
  };
}
