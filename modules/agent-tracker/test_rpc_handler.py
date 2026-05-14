import datetime
import json
import os
import unittest
from unittest import mock

import rpc_handler
import state


class TestRpcHandler(unittest.TestCase):
    def setUp(self):
        state.state = {}
        state.name_index = {}

    @mock.patch("tmux_util.set_agent_uuid")
    @mock.patch("tmux_util.set_agent_id")
    def test_register_same_agent_id_preserves_runtime_state(self, _set_agent_id, _set_agent_uuid):
        state.set_agent(
            "agent1",
            {
                "agent_id": "id-1",
                "status": "working",
                "waiting_approval": True,
                "pending_notifications": ["peer-agent"],
                "pid": 12345,
                "session": "old-session",
                "tmux_pane": "%1",
                "tmux_socket": "old-sock",
                "wrapper_pid": 111,
                "agent_type": "pi",
                "agent_cmd": "pi",
            },
        )

        name = rpc_handler.handle_register(
            {
                "session": "new-session",
                "tmux_pane": "%2",
                "wrapper_pid": 222,
                "tmux_socket": "new-sock",
                "name": "agent1",
                "agent_type": "pi",
                "agent_cmd": "pi",
                "agent_id": "id-1",
            }
        )

        self.assertEqual(name, "agent1")
        info = state.get_agent("agent1")
        self.assertEqual(info["agent_id"], "id-1")
        self.assertEqual(info["status"], "working")
        self.assertTrue(info["waiting_approval"])
        self.assertEqual(info["pending_notifications"], ["peer-agent"])
        self.assertEqual(info["pid"], 12345)
        self.assertEqual(info["session"], "new-session")
        self.assertEqual(info["tmux_pane"], "%2")
        self.assertEqual(info["tmux_socket"], "new-sock")
        self.assertEqual(info["wrapper_pid"], 222)
        self.assertIn("last_heartbeat", info)
        self.assertEqual(len(state.state), 1)

    @mock.patch("rpc_handler.time.time", return_value=123.0)
    @mock.patch("tmux_util.set_agent_uuid")
    @mock.patch("tmux_util.set_agent_id")
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
    def test_register_clears_recovered_at_after_recovery(
        self,
        _list_panes,
        _get_pane_info,
        _discover_agent_process,
        _set_agent_id,
        _set_agent_uuid,
        _time,
    ):
        state.init_state()
        recovered = state.get_agent("agent1")
        self.assertEqual(recovered["status"], "unknown")
        self.assertIsNotNone(recovered["recovered_at"])

        rpc_handler.handle_register(
            {
                "session": "new-session",
                "tmux_pane": "%2",
                "wrapper_pid": 222,
                "tmux_socket": "new-sock",
                "name": "agent1",
                "agent_type": "pi",
                "agent_cmd": "pi",
                "agent_id": "id-1",
            }
        )

        info = state.get_agent("agent1")
        self.assertEqual(info["tmux_pane"], "%2")
        self.assertEqual(info["wrapper_pid"], 222)
        self.assertEqual(info["last_heartbeat"], 123.0)
        self.assertIsNone(info["recovered_at"])

    @mock.patch("rpc_handler.time.time", return_value=456.0)
    def test_heartbeat_clears_recovered_at(self, _time):
        state.set_agent(
            "agent1",
            {
                "agent_id": "id-1",
                "status": "unknown",
                "recovered_at": 100.0,
            },
        )

        self.assertTrue(rpc_handler.handle_heartbeat({"agent_id": "id-1"}))

        info = state.get_agent("agent1")
        self.assertEqual(info["last_heartbeat"], 456.0)
        self.assertIsNone(info["recovered_at"])

    @mock.patch("tmux_util.set_agent_uuid")
    @mock.patch("tmux_util.set_agent_id")
    @mock.patch("state.discover_agent_process", return_value=None)
    @mock.patch("tmux_util.get_pane_info", return_value={"tty": "/dev/pts/1", "session": "sess", "pid": 101})
    @mock.patch("tmux_util.list_panes", return_value=[{
        "pane_id": "%1",
        "agent_name": "agent2",
        "agent_id": "id-1",
        "agent_uuid": "id-1",
        "agent_type": "pi",
        "agent_cmd": "pi",
        "pane_active": False,
    }])
    @mock.patch("subprocess.run")
    @mock.patch("tmux_util.set_pane_title_sync")
    @mock.patch("tmux_util.set_agent_name_sync")
    def test_recovery_prefers_tmux_name_over_stale_register_name(
        self,
        _set_agent_name_sync,
        _set_pane_title_sync,
        _subprocess_run,
        _list_panes,
        _get_pane_info,
        _discover_agent_process,
        _set_agent_id,
        _set_agent_uuid,
    ):
        state.set_agent(
            "agent1",
            {
                "agent_id": "id-1",
                "status": "idle",
                "tmux_pane": "%1",
                "tmux_socket": "sock",
            },
        )
        self.assertTrue(rpc_handler.handle_rename({"old_name": "agent1", "new_name": "agent2", "force": True}))
        self.assertIsNotNone(state.get_agent("agent2"))

        state.state = {}
        state.name_index = {}
        state.init_state()
        self.assertIsNotNone(state.get_agent("agent2"))

        assigned_name = rpc_handler.handle_register(
            {
                "session": "new-session",
                "tmux_pane": "%2",
                "wrapper_pid": 222,
                "tmux_socket": "new-sock",
                "name": "agent1",
                "agent_type": "pi",
                "agent_cmd": "pi",
                "agent_id": "id-1",
            }
        )

        self.assertEqual(assigned_name, "agent2")
        self.assertIsNone(state.get_agent("agent1"))
        info = state.get_agent("agent2")
        self.assertEqual(info["agent_id"], "id-1")
        self.assertEqual(info["tmux_pane"], "%2")

    def test_send_message_targets_agent_id(self):
        inbox_path = "/tmp/agent-inboxes/id-1.inbox"
        try:
            if os.path.exists(inbox_path):
                os.remove(inbox_path)
            state.set_agent(
                "agent1",
                {
                    "agent_id": "id-1",
                    "status": "working",
                    "waiting_approval": False,
                    "pending_notifications": [],
                    "tmux_pane": "%1",
                    "tmux_socket": "sock",
                },
            )
            self.assertTrue(
                rpc_handler.handle_send_message({"agent_id": "id-1", "message": "hello", "sender_name": "tester"})
            )
            info = state.get_agent("agent1")
            self.assertEqual(info["pending_notifications"], ["tester"])
            with open(inbox_path, "r") as f:
                message = json.loads(f.readline())
            timestamp = datetime.datetime.fromisoformat(message["timestamp"])
            self.assertIsNotNone(timestamp.tzinfo)
            self.assertIsNotNone(timestamp.utcoffset())
        finally:
            if os.path.exists(inbox_path):
                os.remove(inbox_path)

    @mock.patch("tmux_util.send_keys")
    def test_send_message_notifies_recovered_unknown_agent(self, send_keys):
        inbox_path = "/tmp/agent-inboxes/id-1.inbox"
        try:
            if os.path.exists(inbox_path):
                os.remove(inbox_path)
            state.set_agent(
                "agent1",
                {
                    "agent_id": "id-1",
                    "status": "unknown",
                    "waiting_approval": False,
                    "pending_notifications": [],
                    "tmux_pane": "%1",
                    "tmux_socket": "sock",
                },
            )

            self.assertTrue(
                rpc_handler.handle_send_message({"agent_id": "id-1", "message": "hello", "sender_name": "tester"})
            )

            info = state.get_agent("agent1")
            self.assertEqual(info["pending_notifications"], [])
            send_keys.assert_called_once_with("%1", "New message in inbox from tester", "sock")
        finally:
            if os.path.exists(inbox_path):
                os.remove(inbox_path)


if __name__ == "__main__":
    unittest.main()
