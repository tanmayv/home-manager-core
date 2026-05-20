{ pkgs, config, userSettings ? {}, ... }:

let
  agentWrapperPackage = import ./agent-wrapper-package.nix { inherit pkgs config; };
  agentTrackerSettings = userSettings.agent-tracker or {};
  registryUrl = agentTrackerSettings.registry-url or null;
  agentCommunicatorTui = pkgs.buildGoModule {
    pname = "agent-communicator";
    version = "0.1.0";
    src = ../../agent-communicator-tui;
    vendorHash = "sha256-uwBJAqN4sIepiiJf9lCDumLqfKJEowQO2tOiSWD3Fig=";
    ldflags = [ "-X main.version=0.1.0" ];
  };
  registryEnv = if registryUrl == null then "" else ''
    export AGENT_REGISTRY_URL=${pkgs.lib.escapeShellArg registryUrl}
  '';
in
{
  home.packages = [
    agentCommunicatorTui
    (pkgs.writeShellApplication {
      name = "agent-communicator";
      runtimeInputs = [ agentWrapperPackage ];
      text = ''
        ${registryEnv}
        export SUGGESTED_AGENT_NAME="''${SUGGESTED_AGENT_NAME:-agent-communicator}"
        export AGENT_ID="''${AGENT_ID:-00000000-0000-5000-8000-000000000001}"
        exec agent-wrapper ${agentCommunicatorTui}/bin/agent-communicator-tui --no-notify-with-send-keys "$@"
      '';
    })
  ];
}
