self: { config, lib, pkgs, ... }:
let
  cfg = config.services.agent-registry;
in {
  options.services.agent-registry = with lib; {
    enable = mkEnableOption "agent-registry";
    port = mkOption { type = types.port; default = 8080; };
    auth = mkOption { type = types.bool; default = true; };
    tokenFile = mkOption { type = types.nullOr types.path; default = null; };
    staleSeconds = mkOption { type = types.int; default = 60; };
    goneSeconds = mkOption { type = types.int; default = 180; };
  };
  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = !cfg.auth || cfg.tokenFile != null;
      message = "services.agent-registry.tokenFile is required when auth is enabled.";
    }];
    systemd.services.agent-registry = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        EnvironmentFile = pkgs.writeText "agent-registry.env" ''
          AGENT_REGISTRY_PORT=${toString cfg.port}
          AGENT_REGISTRY_AUTH=${if cfg.auth then "true" else "false"}
          TRACKER_STALE_SECONDS=${toString cfg.staleSeconds}
          TRACKER_GONE_SECONDS=${toString cfg.goneSeconds}
        '';
        LoadCredential = lib.optional cfg.auth "registry-token:${cfg.tokenFile}";
        ExecStart = toString (pkgs.writeShellScript "agent-registry-start" ''
          ${lib.optionalString cfg.auth ''export AGENT_REGISTRY_TOKEN="$(cat "$CREDENTIALS_DIRECTORY/registry-token")"''}
          exec ${self.packages.${pkgs.system}.default}/bin/agent-registry
        '');
        Restart = "always";
      };
    };
  };
}
