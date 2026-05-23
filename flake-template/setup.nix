{
  system = "x86_64-linux"; # e.g. "aarch64-darwin" for Apple Silicon macOS
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
  tmuxShortcut = "b"; # tmux prefix key: "b" means Ctrl-b, "a" means Ctrl-a

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
  };
}
