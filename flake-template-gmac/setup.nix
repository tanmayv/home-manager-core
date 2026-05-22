{
  system = "aarch64-darwin";
  username = "your-username";
  config-location = "~/.config/home-manager";
  local_agent_knowledge_dir = "~/agent_knowledge";
  local_agent_knowledge_create_command = "";
  editor = "nvim";
  theme = "everforest";
  preferred-scripting-language = "Python";

  enable_bash_over_zsh = false;
  enable-ai-workflow = true;
  enable-neovim = true;
  enable-tasks = true;
  enable-tmux-on-ssh = false; # usually false on macOS laptop
  auto-switch-workspace-on-cd = false;
  auto-switch-workspace-on-hgd = false;
  import-extras = true;
  enable-smart-cd = true;
  smart-cd-max-parents = 4;
  enable-cd-verbose = true;
  enable-auto-codesearch-with-cd = false;
  sessionizerMaxDirLength = 25;
  sessionizerSearchPaths = [ "~" "~/projects" ];

  enable-agent-tracker = true;
  enable-agent-communicator = true;
  agent-tracker = {
    registries = []; # e.g. [{ name = "corp"; url = "https://agents.example"; token-file = null; }]
    registry-auth = false;
    registry-token-file = null; # required when registry-auth = true
    http-port = 19876;
    registry-heartbeat-seconds = 30;
  };
  enable-skill-publishing = false;
  skill-publishing = {
    target-path = "";
  };

  ai_features = {
    enable_agent_knowledge = true;
    enable_ai_ssa_creator_skill = true;
    enable_tmux_based_agent_comms = true;
  };
}
