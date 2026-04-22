{
  username = "tanmayvijay";
  config-location = "~/minimal-cloudtop";
  local_agent_knowledge_dir = "~/pkm/dots";
  local_agent_knowledge_create_command = "nn --print-path"; # e.g., "nn"
  editor = "nvim";
  enable-ai-workflow = true;
  enable-neovim = true;
  enable-tmux-on-ssh = true;
  auto-switch-workspace-on-hgd = true;
  enable-cd-verbose = true;
  import-extras = true;
  enable-smart-cd = true;
  smart-cd-max-parents = 4;
  enable-auto-codesearch-with-cd = true;
  preferred-scripting-language = "NuShell";
  enable-agent-tracker = true;
  enable-skill-publishing = false;
  skill-publishing = {
    # Target path in piper. $USER will be replaced with your LDAP.
    target-path = "//depot/configs/users/$USER/_agents/skills";
  };
  ai_features = {
    enable_agent_knowledge = true;
    enable_ai_ssa_creator_skill = true;
    enable_tmux_based_agent_comms = true;
    enable_home_manager_skill = true;
  };
}
