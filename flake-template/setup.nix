{
  username = "your-username";
  config-location = "~/.config/home-manager";
  local_agent_knowledge_dir = "~/agent_knowledge";
  local_agent_knowledge_create_command = ""; # command/script that prints the path of the note to be updated.
  editor = "nvim";
  preferred-scripting-language = "NuShell";

  enable_bash_over_zsh = false;
  enable-ai-workflow = true;
  enable-neovim = true;
  enable-tasks = true;
  enable-tmux-on-ssh = true;
  auto-switch-workspace-on-cd = false;
  auto-switch-workspace-on-hgd = true;
  import-extras = true;
  enable-smart-cd = true;
  smart-cd-max-parents = 4;
  enable-cd-verbose = true;
  enable-auto-codesearch-with-cd = true;
  sessionizerMaxDirLength = 25;
  sessionizerSearchPaths = [ "~" "~/projects/nix" ];

  enable-agent-tracker = true;
  enable-skill-publishing = false;
  skill-publishing = {
    # Target path in piper. $USER will be replaced with your LDAP.
    target-path = "//depot/configs/users/$USER/_agents/skills";
  };

  # Custom AI agents to wrap with agent-wrapper
  # custom-agents = {
  #   claude = "/path/to/claude";
  # };

  ai_features = {
    enable_agent_knowledge = true;
    enable_ai_ssa_creator_skill = true;
    enable_tmux_based_agent_comms = true;
    enable_home_manager_skill = true;
  };
}
