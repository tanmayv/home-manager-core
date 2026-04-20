{
  username = "tanmayvijay";
  config-location = "~/.config/minimal-cloudtop";
  local_agent_knowledge_dir = "~/agent_knowledge";
  local_agent_knowledge_create_command = ""; # e.g., "nn"
  editor = "nvim";
  enable-ai-workflow = false;
  enable-neovim = true;
  enable-tmux-on-ssh = true;
  auto-switch-workspace-on-hgd = true;
  enable-cd-verbose = true;
  import-extras = true;
  ai_features = {
    enable_agent_knowledge = false;
    enable_ai_ssa_creator_skill = false;
    enable_tmux_based_agent_comms = false;
  };
}
