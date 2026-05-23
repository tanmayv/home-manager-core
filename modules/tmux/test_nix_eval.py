import json
import os
import subprocess
import unittest


class TestTmuxNixEval(unittest.TestCase):
    def _eval_shortcut(self, user_settings: str) -> str:
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
      {repo}/modules/tmux/default.nix
      {{ home.username = "u"; home.homeDirectory = "/tmp/u"; home.stateVersion = "24.05"; }}
    ];
    extraSpecialArgs = {{ userSettings = {user_settings}; }};
  }};
in builtins.toJSON cfg.config.programs.tmux.shortcut
'''
        out = subprocess.check_output(["nix", "eval", "--impure", "--raw", "--expr", expr], text=True).strip()
        return json.loads(out)

    def test_tmux_shortcut_defaults_to_ctrl_b_suffix(self):
        self.assertEqual(self._eval_shortcut("{}"), "b")

    def test_tmux_shortcut_accepts_user_settings_camel_case(self):
        self.assertEqual(self._eval_shortcut('{ tmuxShortcut = "a"; }'), "a")

    def test_tmux_shortcut_accepts_user_settings_kebab_case(self):
        self.assertEqual(self._eval_shortcut('{ "tmux-prefix" = "a"; }'), "a")


if __name__ == "__main__":
    unittest.main()
