import unittest
from unittest import mock

import registry_client
import state


class TestRegistryEvents(unittest.TestCase):
    def setUp(self):
        state.state = {}
        state.name_index = {}
        state.pane_index = {}

    def test_event_loop_publishes_local_message_read_and_acks(self):
        event = {
            "event_id": "e1",
            "event_type": "message_read",
            "payload": {"message_id": "m1", "sender_agent_id": "s1", "reader_agent_id": "r1", "reader_agent_name": "remote"},
        }
        state.set_agent("agent-communicator", {"agent_id": "s1"})
        with mock.patch.object(registry_client, "fetch_events", side_effect=[(200, {"events": [event]}), SystemExit]), \
             mock.patch.object(registry_client, "ack_event", return_value=200) as ack, \
             mock.patch.object(state, "publish_event") as publish:
            with self.assertRaises(SystemExit):
                registry_client._event_loop()
        publish.assert_called_once_with("message_read", {"target_agent_id": "r1", "target_agent_name": "remote", "sender": "agent-communicator", "message_id": "m1"})
        ack.assert_called_once_with("e1")


if __name__ == "__main__":
    unittest.main()
