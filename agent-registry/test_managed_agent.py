import importlib.util
import os
import unittest
from unittest import mock

_MOD_PATH = os.path.join(os.path.dirname(__file__), "managed_agent.py")
_spec = importlib.util.spec_from_file_location("managed_agent", _MOD_PATH)
managed_agent = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(managed_agent)


class TestManagedAgent(unittest.TestCase):
    def test_build_launch_command_includes_wrapper_and_env(self):
        cmd = managed_agent.build_launch_command("nixos-expert", "pi --help", "/tmp/tracker.sock")
        self.assertIn("SUGGESTED_AGENT_NAME=nixos-expert", cmd)
        self.assertIn("AGENT_TRACKER_SOCKET=/tmp/tracker.sock", cmd)
        self.assertIn("agent-wrapper", cmd)
        self.assertIn("pi --help", cmd)

    @mock.patch.object(managed_agent, "ensure_requirements")
    @mock.patch.object(managed_agent, "list_panes", return_value=[{"pane_id": "%1", "pane_dead": False, "pane_current_command": "pi", "agent_name": "nixos-expert"}])
    @mock.patch.object(managed_agent, "ensure_session", return_value=False)
    def test_reconcile_agent_noop_when_named_agent_exists(self, _session, _panes, _reqs):
        self.assertEqual(
            managed_agent.reconcile_agent("nixos-expert", "sess", "/tmp", "pi"),
            "already-running",
        )

    @mock.patch.object(managed_agent, "ensure_requirements")
    @mock.patch.object(managed_agent, "tmux_cmd")
    @mock.patch.object(managed_agent, "list_panes", return_value=[])
    @mock.patch.object(managed_agent, "ensure_session", return_value=True)
    def test_reconcile_agent_starts_new_window(self, _session, _panes, tmux_cmd, _reqs):
        self.assertEqual(
            managed_agent.reconcile_agent("nixos-expert", "sess", "/tmp", "pi"),
            "session-created-started",
        )
        args = tmux_cmd.call_args[0][0]
        self.assertEqual(args[:5], ["new-window", "-d", "-t", "sess", "-n"])
        self.assertEqual(args[5], "nixos-expert")

    @mock.patch.object(managed_agent, "ensure_requirements")
    @mock.patch.object(managed_agent, "tmux_cmd")
    @mock.patch.object(managed_agent, "list_panes", return_value=[{"pane_id": "%1", "pane_dead": True, "pane_current_command": "bash", "agent_name": "nixos-expert"}])
    @mock.patch.object(managed_agent, "ensure_session", return_value=False)
    def test_reconcile_agent_respawns_dead_named_pane(self, _session, _panes, tmux_cmd, _reqs):
        self.assertEqual(
            managed_agent.reconcile_agent("nixos-expert", "sess", "/tmp", "pi"),
            "respawned",
        )
        args = tmux_cmd.call_args[0][0]
        self.assertEqual(args[:4], ["respawn-pane", "-k", "-t", "%1"])


if __name__ == "__main__":
    unittest.main()
