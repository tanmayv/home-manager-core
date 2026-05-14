import unittest
from unittest import mock
import state

class TestState(unittest.TestCase):
    def setUp(self):
        state.state = {}  # Reset state
        state.name_index = {}

    def test_set_get_agent(self):
        state.set_agent("agent1", {"status": "idle", "agent_id": "id-1"})
        info = state.get_agent("agent1")
        self.assertEqual(info["status"], "idle")
        self.assertEqual(info["agent_id"], "id-1")
        self.assertEqual(state.get_agent("id-1")["status"], "idle")

    def test_update_agent(self):
        state.set_agent("agent1", {"status": "idle"})
        self.assertTrue(state.update_agent("agent1", status="working"))
        self.assertEqual(state.get_agent("agent1")["status"], "working")

    def test_rename_agent(self):
        state.set_agent("agent1", {"status": "idle", "agent_id": "id-1"})
        self.assertTrue(state.rename_agent("agent1", "agent2"))
        self.assertIsNotNone(state.get_agent("agent1"))
        self.assertEqual(state.get_agent("agent2")["status"], "idle")
        self.assertEqual(state.get_agent("agent2")["agent_id"], "id-1")
        self.assertEqual(state.get_agent("agent2")["aliases"], ["agent1"])
        self.assertEqual(state.get_agent_name_by_id("id-1"), "agent2")

    def test_delete_agent(self):
        state.set_agent("agent1", {"status": "idle", "agent_id": "id-1"})
        state.rename_agent("agent1", "agent2")
        state.delete_agent("id-1")
        self.assertIsNone(state.get_agent("agent2"))
        self.assertIsNone(state.get_agent("agent1"))
        self.assertIsNone(state.get_agent("id-1"))

    def test_upsert_by_agent_id_replaces_old_name(self):
        state.set_agent("agent1", {"status": "idle", "agent_id": "id-1", "tmux_pane": "%1"})
        state.set_agent("agent2", {"status": "working", "agent_id": "id-1", "tmux_pane": "%2"})
        self.assertIsNotNone(state.get_agent("agent1"))
        self.assertEqual(state.get_agent("agent2")["status"], "working")
        self.assertEqual(state.get_agent("agent2")["aliases"], ["agent1"])
        self.assertEqual(state.get_agent_name_by_id("id-1"), "agent2")
        self.assertEqual(state.get_agent_name_by_pane("%2"), "agent2")

    def test_name_reuse_evicts_old_agent_id(self):
        state.set_agent("agent1", {"status": "spawning", "agent_id": "spawn-id"})
        state.set_agent("agent1", {"status": "idle", "agent_id": "real-id", "tmux_pane": "%3"})
        self.assertIsNone(state.get_agent("spawn-id"))
        self.assertEqual(state.get_agent("agent1")["agent_id"], "real-id")
        self.assertEqual(state.get_agent_name_by_id("real-id"), "agent1")

    @mock.patch("state.discover_agent_process", return_value=None)
    @mock.patch("tmux_util.get_pane_info", return_value={"tty": "/dev/pts/1", "session": "sess", "pid": 101})
    @mock.patch("tmux_util.list_panes", return_value=[{
        "pane_id": "%1",
        "agent_name": "agent1",
        "agent_id": "id-1",
        "agent_uuid": "id-1",
        "agent_type": "pi",
        "agent_cmd": "pi",
        "pane_active": False,
    }])
    def test_init_state_recovers_without_live_process(self, _list_panes, _get_pane_info, _discover_agent_process):
        state.init_state()
        info = state.get_agent("agent1")
        self.assertIsNotNone(info)
        self.assertEqual(info["agent_id"], "id-1")
        self.assertEqual(info["status"], "unknown")
        self.assertIsNone(info["pid"])

if __name__ == '__main__':
    unittest.main()
