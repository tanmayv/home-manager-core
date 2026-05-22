{ pkgs, config, lib, userSettings ? {}, ... }:

let
  aiFeatures = userSettings.ai_features or {};
  defaultEnable =
    if userSettings ? enable-agent-communicator then userSettings.enable-agent-communicator
    else if aiFeatures ? enable_agent_communicator then aiFeatures.enable_agent_communicator
    else true;

  cfg = config.programs.agent-communicator;
  agentWrapperPackage = import ./agent-wrapper-package.nix { inherit pkgs config; };
  agentCommunicatorTui = pkgs.buildGoModule {
    pname = "agent-communicator";
    version = "0.1.0";
    src = ../../agent-communicator-tui;
    vendorHash = "sha256-TUbaUoqDZoQTkcOMtoE/FlAiqkWN+x49JeGkDguh2UU=";
    ldflags = [ "-X main.version=0.1.0" ];
  };
in
{
  options.programs.agent-communicator.enable = lib.mkOption {
    type = lib.types.bool;
    default = defaultEnable;
    description = "Whether to install the agent-communicator TUI and wrapper launcher.";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."agent-communicator/prompts/test.md".text = ''
      Please summarize the current status and list any next actions.
    '';

    home.packages = [
      agentCommunicatorTui
      (pkgs.writeShellApplication {
        name = "agent-communicator";
        runtimeInputs = [ agentWrapperPackage ];
        text = ''
          export SUGGESTED_AGENT_NAME="''${SUGGESTED_AGENT_NAME:-agent-communicator}"
          export AGENT_ID="''${AGENT_ID:-00000000-0000-5000-8000-000000000001}"
          mkdir -p "''${XDG_CONFIG_HOME:-$HOME/.config}/agent-communicator/prompts"
          exec agent-wrapper ${agentCommunicatorTui}/bin/agent-communicator-tui --no-notify-with-send-keys "$@"
        '';
      })
    ];
  };
}
