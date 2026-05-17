import importlib.util
import json
import os
import tempfile
import unittest
from unittest import mock

_CTL_PATH = os.path.join(os.path.dirname(__file__), "agent-tracker-ctl.py")
_spec = importlib.util.spec_from_file_location("agent_tracker_ctl", _CTL_PATH)
ctl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ctl)


class TestAgentTrackerCtl(unittest.TestCase):
    def test_format_status_bar_shows_green_registry_indicator_when_connected(self):
        bar = ctl.format_status_bar(
            {"agent1": {"tmux_pane": "%1", "status": "idle"}},
            "%2",
            registry_connected=True,
        )
        self.assertIn("Active Agents:", bar)
        self.assertTrue(bar.endswith(" #[fg=#9ece6a,bold]●#[default]"))

    def test_format_status_bar_shows_red_registry_indicator_when_disconnected(self):
        bar = ctl.format_status_bar(
            {"agent1": {"tmux_pane": "%1", "status": "idle"}},
            "%2",
            registry_connected=False,
        )
        self.assertTrue(bar.endswith(" #[fg=#db4b4b,bold]●#[default]"))

    def test_is_registry_connected_requires_fresh_success(self):
        with tempfile.TemporaryDirectory() as tmp:
            status_path = os.path.join(tmp, "registry-status.json")
            with open(status_path, "w") as f:
                json.dump({"connected": True, "last_success": 100.0}, f)
            with mock.patch.object(ctl, "REGISTRY_STATUS_PATH", status_path), \
                 mock.patch.dict(os.environ, {"AGENT_REGISTRY_URL": "https://agents.mundus.in", "AGENT_REGISTRY_HEARTBEAT_SECONDS": "30"}, clear=False):
                self.assertTrue(ctl.is_registry_connected(now=120.0))
                self.assertFalse(ctl.is_registry_connected(now=200.0))


if __name__ == "__main__":
    unittest.main()
