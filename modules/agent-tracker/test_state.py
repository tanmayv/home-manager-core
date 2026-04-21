import unittest
import state

class TestState(unittest.TestCase):
    def setUp(self):
        state.state = {} # Reset state

    def test_set_get_agent(self):
        info = {"status": "idle"}
        state.set_agent("agent1", info)
        self.assertEqual(state.get_agent("agent1"), info)

    def test_update_agent(self):
        state.set_agent("agent1", {"status": "idle"})
        self.assertTrue(state.update_agent("agent1", status="working"))
        self.assertEqual(state.get_agent("agent1")["status"], "working")

    def test_rename_agent(self):
        state.set_agent("agent1", {"status": "idle"})
        self.assertTrue(state.rename_agent("agent1", "agent2"))
        self.assertIsNone(state.get_agent("agent1"))
        self.assertEqual(state.get_agent("agent2")["status"], "idle")

    def test_delete_agent(self):
        state.set_agent("agent1", {"status": "idle"})
        state.delete_agent("agent1")
        self.assertIsNone(state.get_agent("agent1"))

if __name__ == '__main__':
    unittest.main()
