import unittest
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
        self.assertIsNone(state.get_agent("agent1"))
        self.assertEqual(state.get_agent("agent2")["status"], "idle")
        self.assertEqual(state.get_agent("agent2")["agent_id"], "id-1")
        self.assertEqual(state.get_agent_name_by_id("id-1"), "agent2")

    def test_delete_agent(self):
        state.set_agent("agent1", {"status": "idle", "agent_id": "id-1"})
        state.delete_agent("id-1")
        self.assertIsNone(state.get_agent("agent1"))
        self.assertIsNone(state.get_agent("id-1"))

    def test_upsert_by_agent_id_replaces_old_name(self):
        state.set_agent("agent1", {"status": "idle", "agent_id": "id-1", "tmux_pane": "%1"})
        state.set_agent("agent2", {"status": "working", "agent_id": "id-1", "tmux_pane": "%2"})
        self.assertIsNone(state.get_agent("agent1"))
        self.assertEqual(state.get_agent("agent2")["status"], "working")
        self.assertEqual(state.get_agent_name_by_id("id-1"), "agent2")
        self.assertEqual(state.get_agent_name_by_pane("%2"), "agent2")

    def test_name_reuse_evicts_old_agent_id(self):
        state.set_agent("agent1", {"status": "spawning", "agent_id": "spawn-id"})
        state.set_agent("agent1", {"status": "idle", "agent_id": "real-id", "tmux_pane": "%3"})
        self.assertIsNone(state.get_agent("spawn-id"))
        self.assertEqual(state.get_agent("agent1")["agent_id"], "real-id")
        self.assertEqual(state.get_agent_name_by_id("real-id"), "agent1")

if __name__ == '__main__':
    unittest.main()
