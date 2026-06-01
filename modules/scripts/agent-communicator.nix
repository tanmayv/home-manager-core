{ pkgs, config, lib, userSettings ? {}, ... }:

let
  aiFeatures = userSettings.ai_features or {};
  defaultEnable =
    if userSettings ? enable-agent-communicator then userSettings.enable-agent-communicator
    else if aiFeatures ? enable_agent_communicator then aiFeatures.enable_agent_communicator
    else true;

  cfg = config.programs.agent-communicator;
in
{
  options.programs.agent-communicator.enable = lib.mkOption {
    type = lib.types.bool;
    default = defaultEnable;
    description = "Whether to install the agent-communicator compatibility launcher.";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."agent-communicator/prompts/test.md".text = ''
      Please summarize the current status and list any next actions.
    '';

    home.packages = [
      (pkgs.writeShellApplication {
        name = "agent-communicator";
        runtimeInputs = [ config.programs.broccoli-comms.package ];
        text = ''
          mkdir -p "''${XDG_CONFIG_HOME:-$HOME/.config}/agent-communicator/prompts"
          exec broccoli-comms ui
        '';
      })
    ];
  };
}
