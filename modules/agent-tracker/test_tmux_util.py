import unittest
from unittest import mock
import time

import tmux_util


class TestTmuxUtil(unittest.TestCase):
    def setUp(self):
        # Reset the global state before each test
        tmux_util.last_send_keys_time = 0.0

    @mock.patch("tmux_util.enqueue_tmux_cmd")
    def test_send_keys_rate_limiting_gap(self, mock_enqueue):
        # 1. Trigger first send_keys (initial state)
        start_time = time.time()
        tmux_util.send_keys("%1", "hello")

        # Verify the enqueued calls for the first send_keys
        # Expecting: send-keys keys, sleep 0.5, send-keys Enter
        self.assertEqual(mock_enqueue.call_count, 3)
        mock_enqueue.assert_any_call(["tmux", "send-keys", "-t", "%1", "hello"])
        mock_enqueue.assert_any_call(["sleep", "0.5"])
        mock_enqueue.assert_any_call(["tmux", "send-keys", "-t", "%1", "Enter"])

        # Reset mock call tracking
        mock_enqueue.reset_mock()

        # 2. Trigger second send_keys immediately after
        tmux_util.send_keys("%1", "world")

        # Expecting: sleep delay, send-keys keys, sleep 0.5, send-keys Enter
        self.assertEqual(mock_enqueue.call_count, 4)
        
        # Extract the enqueued sleep command and verify the delay
        sleep_call = mock_enqueue.call_args_list[0][0][0]
        self.assertEqual(sleep_call[0], "sleep")
        delay = float(sleep_call[1])
        
        # Delay should be approximately 3.5 seconds (3.0s gap + 0.5s enqueued sleep in first call)
        self.assertTrue(3.0 <= delay <= 3.7, f"Expected delay to be around 3.5s, got {delay}s")
        
        mock_enqueue.assert_any_call(["tmux", "send-keys", "-t", "%1", "world"])
        mock_enqueue.assert_any_call(["sleep", "0.5"])
        mock_enqueue.assert_any_call(["tmux", "send-keys", "-t", "%1", "Enter"])


if __name__ == "__main__":
    unittest.main()
