{ pkgs, userSettings ? {}, ... }:

let
  enableAiWorkflow = userSettings.enable-ai-workflow or false;
  aiFeatures = userSettings.ai_features or {
    enable_ai_ssa_creator_skill = false;
    enable_tmux_based_agent_comms = false;
    enable_agent_knowledge = false;
    enable_agent_communicator = false;
  };
  enableAgentComms = enableAiWorkflow && (aiFeatures.enable_tmux_based_agent_comms or false);
  enableAgentCommunicator = enableAgentComms && (aiFeatures.enable_agent_communicator or false);
in
{
  imports = [
    ./fuse_fix.nix
    ./build-and-switch.nix
    ./knowledge-manager.nix

    ./new-gemini-agent.nix
    ./twatch.nix
    ./tmux-rename-agent.nix
  ] ++ (if enableAgentComms then [
    ./iamdone.nix
    ./waiting.nix
    ./send-message-to-agent.nix
    ./agent-wrapper.nix
  ] else []) ++ (if enableAgentCommunicator then [
    ./agent-communicator.nix
  ] else []);
}
