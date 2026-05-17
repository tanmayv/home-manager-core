import os
import subprocess
import unittest


class TestNixEval(unittest.TestCase):
    def test_agent_tracker_enable_default_registry_settings_evaluates(self):
        repo = os.path.dirname(os.path.dirname(os.path.dirname(__file__)))
        expr = f'''
let
  flake = builtins.getFlake "path:{repo}";
  system = builtins.currentSystem;
  pkgs = import flake.inputs.nixpkgs {{ inherit system; }};
  hm = flake.inputs.home-manager;
  cfg = hm.lib.homeManagerConfiguration {{
    inherit pkgs;
    modules = [
      ({{ lib, ... }}: {{
        options.programs.tmux.statusBar.extraLines = lib.mkOption {{ type = lib.types.listOf lib.types.anything; default = []; }};
      }})
      {repo}/modules/agent-tracker/default.nix
      {{ services.agent-tracker.enable = true; home.username = "u"; home.homeDirectory = "/tmp/u"; home.stateVersion = "24.05"; }}
    ];
    extraSpecialArgs = {{ userSettings = {{ }}; }};
  }};
in builtins.toJSON cfg.config.services.agent-tracker.registryAuth
'''
        out = subprocess.check_output(["nix", "eval", "--impure", "--raw", "--expr", expr], text=True).strip()
        self.assertEqual(out, "false")


if __name__ == "__main__":
    unittest.main()
