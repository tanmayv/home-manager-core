{
  # Path to this configuration directory
  config-location = "~/.config/home-manager";

  # Preferred editor
  editor = "vim";

  # AI Workflow Features
  enable-ai-workflow = true;
  ai_features = {
    enable_ai_ssa_creator_skill = true;
    enable_tmux_based_agent_comms = true;
    enable_agent_knowledge = true;
    enable_home_manager_skill = true;
  };

  # Shell Features
  enable-agent-tracker = true;
  enable-smart-cd = true;
  smart-cd-max-parents = 4;
  enable-cd-verbose = true;
  sessionizerMaxDirLength = 25;
  sessionizerSearchPaths = [ "~" ];

  # Git/CitC Features
  auto-switch-workspace-on-hgd = true;

  # Additional Tools
  enable-neovim = false;
  enable-skill-publishing = true;
  skill-publishing = {
    target-path = "//depot/configs/users/$USER/_agents/skills";
  };
}
