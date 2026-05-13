{
  username = "your-username";
  config-location = "~/.config/home-manager";

  editor = "vim";

  enable-ai-workflow = true;
  ai_features = {
    enable_ai_ssa_creator_skill = true;
    enable_tmux_based_agent_comms = true;
    enable_agent_knowledge = true;
    enable_home_manager_skill = true;
  };

  enable-agent-tracker = true;
  enable-smart-cd = true;
  smart-cd-max-parents = 4;
  enable-cd-verbose = true;
  sessionizerMaxDirLength = 25;
  sessionizerSearchPaths = [ "~" ];

  enable-neovim = true;
  enable-skill-publishing = false;
}
