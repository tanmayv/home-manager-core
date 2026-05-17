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
        state.pane_index = {}
        state.INBOX_DIR = "/tmp/test-agent-inboxes"

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
        inbox_path = os.path.join(state.INBOX_DIR, "id-1.inbox")
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
        inbox_path = os.path.join(state.INBOX_DIR, "id-1.inbox")
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

    @mock.patch("tmux_util.set_agent_uuid")
    @mock.patch("tmux_util.set_agent_id")
    def test_simultaneous_wrapper_reconnect_race(self, _set_agent_id, _set_agent_uuid):
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

        name1 = rpc_handler.handle_register(
            {
                "session": "sess",
                "tmux_pane": "%1",
                "wrapper_pid": 111,
                "tmux_socket": "sock",
                "name": "agent1",
                "agent_id": "id-1",
            }
        )
        name2 = rpc_handler.handle_register(
            {
                "session": "sess",
                "tmux_pane": "%1",
                "wrapper_pid": 222,
                "tmux_socket": "sock",
                "name": "agent1",
                "agent_id": "id-1",
            }
        )

        self.assertEqual(name1, "agent1")
        self.assertEqual(name2, "agent1")
        self.assertEqual(len(state.state), 1)
        info = state.get_agent("agent1")
        self.assertEqual(info["wrapper_pid"], 222)
        self.assertEqual(info["status"], "unknown")

    @mock.patch("tmux_util.spin_agent")
    @mock.patch("tmux_util.set_agent_uuid")
    @mock.patch("tmux_util.set_agent_id")
    def test_placeholder_spawning_replaced_by_real_register(self, _set_agent_id, _set_agent_uuid, _spin):
        assigned_name = rpc_handler.handle_spin_agent(
            {"session": "sess", "command": "jetski", "name": "agent1"}
        )
        self.assertEqual(assigned_name, "agent1")
        spawning_info = state.get_agent("agent1")
        self.assertEqual(spawning_info["status"], "spawning")

        real_name = rpc_handler.handle_register(
            {
                "session": "sess",
                "tmux_pane": "%2",
                "wrapper_pid": 333,
                "tmux_socket": "sock",
                "name": "agent1",
                "agent_id": "real-uuid-123",
            }
        )
        self.assertEqual(real_name, "agent1")
        self.assertEqual(len(state.state), 1)
        info = state.get_agent("agent1")
        self.assertEqual(info["agent_id"], "real-uuid-123")
        self.assertEqual(info["status"], "idle")

    @mock.patch("tmux_util.send_keys")
    def test_busy_agent_pending_notification_flush(self, send_keys):
        inbox_path = os.path.join(state.INBOX_DIR, "id-1.inbox")
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
                rpc_handler.handle_send_message({"agent_id": "id-1", "message": "msg1", "sender_name": "alice"})
            )
            self.assertTrue(
                rpc_handler.handle_send_message({"agent_id": "id-1", "message": "msg2", "sender_name": "bob"})
            )

            info = state.get_agent("agent1")
            self.assertEqual(info["pending_notifications"], ["alice", "bob"])
            send_keys.assert_not_called()

            rpc_handler.handle_update_agent({"agent_name": "agent1", "status": "idle"})

            info = state.get_agent("agent1")
            self.assertEqual(info["pending_notifications"], [])
            self.assertEqual(send_keys.call_count, 2)
            send_keys.assert_any_call("%1", "New message in inbox from alice", "sock")
            send_keys.assert_any_call("%1", "New message in inbox from bob", "sock")
        finally:
            if os.path.exists(inbox_path):
                os.remove(inbox_path)


if __name__ == "__main__":
    unittest.main()
