{ lib, ... }:

with lib;

{
  options.services.agent-tracker = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable agent-tracker daemon";
    };

    enableTmuxIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Enable agent-related tmux configuration (status bar, keybindings)";
    };

    agents = mkOption {
      type = types.attrsOf types.str;
      default = {};
      description = "Map of agent aliases to their executable paths.";
    };
  };
}
