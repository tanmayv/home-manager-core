{
  username = "tanmayvijay";
  config-location = "~/.config/minimal-cloudtop";
  local_agent_knowledge_dir = "~/agent_knowledge";
  local_agent_knowledge_create_command = ""; # e.g., "nn"
  editor = "nvim";
  enable-ai-workflow = true;
  enable-neovim = true;
  enable-tmux-on-ssh = true;
  auto-switch-workspace-on-hgd = true;
  enable-cd-verbose = true;
  import-extras = true;
  ai_features = {
    enable_ai_ssa_creator_skill = true;
    enable_tmux_based_agent_comms = true;
  };
}
