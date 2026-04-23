{ pkgs, userSettings, ... }:

let
  enableAiWorkflow = userSettings.enable-ai-workflow or false;
  aiFeatures = userSettings.ai_features or {
    enable_ai_ssa_creator_skill = false;
    enable_tmux_based_agent_comms = false;
    enable_agent_knowledge = false;
  };
  enableAgentComms = enableAiWorkflow && (aiFeatures.enable_tmux_based_agent_comms or false);
in
{
  imports = [
    ./fuse_fix.nix
    ./build-and-switch.nix
    ./tmux-cs-fzf.nix
    ./tmux-cs-cd.nix
    ./ai-wrappers.nix
    ./knowledge-manager.nix
    ./check-for-update.nix
    ./new-gemini-agent.nix
    ./twatch.nix
  ] ++ (if userSettings.enable-skill-publishing or false then [
    ./skill-ctl.nix
  ] else []) ++ (if enableAgentComms then [
    ./iamdone.nix
    ./waiting.nix
    ./send-message-to-agent.nix
    ./agent-wrapper.nix
  ] else []);
}
