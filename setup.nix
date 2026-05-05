{
  username = "tanmayvijay";
  config-location = "~/minimal-cloudtop";
  local_agent_knowledge_dir = "~/pkm/dots/";
  local_agent_knowledge_create_command = "nn --print-path"; # command/script that prints the path of the note to be updated.
  editor = "nvim";
  enable_bash_over_zsh = false;
  enable-ai-workflow = true;
  enable-neovim = true;
  enable-tmux-on-ssh = true;
  auto-switch-workspace-on-hgd = true;
  enable-cd-verbose = true;
  import-extras = true;
  enable-smart-cd = true;
  smart-cd-max-parents = 4;
  enable-auto-codesearch-with-cd = true;
  preferred-scripting-language = "Python";
  enable-agent-tracker = true;
  enable-skill-publishing = false;
  extra-ai-extensions = [
    # Add paths to other Gemini extensions here
    # e.g., "/google/src/files/head/depot/google3/path/to/team/extension"
  ];
  skill-publishing = {
    # Target path in piper. $USER will be replaced with your LDAP.
    target-path = "//depot/configs/users/$USER/_agents/skills";
    # target-path = "//depot/configs/users/<ldap>/_agents/skills";
  };
  ai_features = {
    enable_agent_knowledge = true;
    enable_ai_ssa_creator_skill = true;
    enable_tmux_based_agent_comms = true;
    enable_home_manager_skill = true;
  };
}
