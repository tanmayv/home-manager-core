import unittest
from unittest import mock

import monitor
import state


class TestMonitor(unittest.TestCase):
    def setUp(self):
        state.state = {}
        state.name_index = {}

    def test_get_liveness_phase_from_heartbeat(self):
        now = 100.0
        self.assertEqual(monitor.get_liveness_phase({"last_heartbeat": 95.0}, now), "fresh")
        self.assertEqual(monitor.get_liveness_phase({"last_heartbeat": 75.0}, now), "stale")
        self.assertEqual(monitor.get_liveness_phase({"last_heartbeat": 60.0}, now), "expired")

    def test_get_liveness_phase_from_recovered_at(self):
        now = 100.0
        self.assertEqual(monitor.get_liveness_phase({"recovered_at": 95.0}, now), "fresh")
        self.assertEqual(monitor.get_liveness_phase({"recovered_at": 75.0}, now), "stale")
        self.assertEqual(monitor.get_liveness_phase({"recovered_at": 60.0}, now), "expired")

    def test_get_liveness_phase_none(self):
        self.assertEqual(monitor.get_liveness_phase({}, 100.0), "none")

    @mock.patch("tmux_util.list_panes", return_value=[{"pane_id": "%1", "pane_active": False}])
    @mock.patch("state.discover_agent_process", return_value={"pid": 321, "comm": "pi"})
    def test_monitor_once_keeps_expired_agent_with_live_pane_process(self, _discover, _list_panes):
        state.set_agent(
            "agent1",
            {
                "agent_id": "id-1",
                "status": "unknown",
                "tmux_pane": "%1",
                "recovered_at": 60.0,
                "wrapper_pid": 123,
                "agent_cmd": "pi",
            },
        )

        monitor.monitor_once(now=100.0)

        info = state.get_agent("agent1")
        self.assertIsNotNone(info)
        self.assertEqual(info["pid"], 321)
        self.assertIsNone(info["wrapper_pid"])

    @mock.patch("tmux_util.list_panes", return_value=[{"pane_id": "%1", "pane_active": False}])
    @mock.patch("state.discover_agent_process", return_value=None)
    def test_monitor_once_removes_expired_agent_without_live_pane_process(self, _discover, _list_panes):
        state.set_agent(
            "agent1",
            {
                "agent_id": "id-1",
                "status": "unknown",
                "tmux_pane": "%1",
                "recovered_at": 60.0,
                "wrapper_pid": 123,
                "agent_cmd": "pi",
            },
        )

        monitor.monitor_once(now=100.0)

        self.assertIsNone(state.get_agent("agent1"))

    @mock.patch("tmux_util.list_panes", return_value=[{"pane_id": "%1", "pane_active": False}])
    @mock.patch("monitor.is_process_alive", return_value=False)
    @mock.patch("state.discover_agent_process", return_value=None)
    def test_kill_9_wrapper_evicts_agent_after_grace_period(self, _discover, _alive, _list_panes):
        state.set_agent(
            "agent1",
            {
                "agent_id": "id-1",
                "status": "working",
                "tmux_pane": "%1",
                "last_heartbeat": 60.0,
                "wrapper_pid": 999,
                "agent_cmd": "jetski",
            },
        )

        monitor.monitor_once(now=100.0)

        self.assertIsNone(state.get_agent("agent1"))


if __name__ == "__main__":
    unittest.main()
