import unittest
from unittest import mock
import time

import tmux_util


class TestTmuxUtil(unittest.TestCase):
    def setUp(self):
        # Reset the global state before each test
        tmux_util.last_send_keys_time = 0.0

    @mock.patch("tmux_util.subprocess.run")
    def test_focus_pane_switches_session_window_and_pane(self, run):
        self.assertTrue(tmux_util.focus_pane("%3", session="work", socket_path="/tmp/tmux.sock"))

        run.assert_has_calls([
            mock.call(["tmux", "-S", "/tmp/tmux.sock", "switch-client", "-t", "work"], check=True, capture_output=True, timeout=5),
            mock.call(["tmux", "-S", "/tmp/tmux.sock", "select-window", "-t", "%3"], check=True, capture_output=True, timeout=5),
            mock.call(["tmux", "-S", "/tmp/tmux.sock", "select-pane", "-t", "%3"], check=True, capture_output=True, timeout=5),
        ])
        self.assertEqual(run.call_count, 3)

    @mock.patch("tmux_util.subprocess.run")
    def test_focus_pane_without_session_selects_window_and_pane(self, run):
        self.assertTrue(tmux_util.focus_pane("%4"))

        run.assert_has_calls([
            mock.call(["tmux", "select-window", "-t", "%4"], check=True, capture_output=True, timeout=5),
            mock.call(["tmux", "select-pane", "-t", "%4"], check=True, capture_output=True, timeout=5),
        ])
        self.assertEqual(run.call_count, 2)

    @mock.patch("tmux_util.subprocess.run")
    def test_focus_pane_is_best_effort(self, run):
        run.side_effect = [Exception("switch failed"), mock.Mock(), mock.Mock()]

        self.assertFalse(tmux_util.focus_pane("%5", session="work"))
        self.assertEqual(run.call_count, 3)

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

    @mock.patch("tmux_util.run_tmux_cmd")
    def test_capture_pane_visible_text_strip_ansi(self, mock_run):
        # Test capturing visible text with ANSI sequence stripping
        mock_run.return_value = "Hello \x1b[31mWorld\x1b[0m!"
        res = tmux_util.capture_pane_visible_text("%0", last_lines=100)
        
        mock_run.assert_called_once_with(["capture-pane", "-p", "-J", "-t", "%0", "-S", "-100"])
        self.assertEqual(res, "Hello World!")

    @mock.patch("tmux_util.run_tmux_cmd")
    def test_capture_pane_visible_text_include_ansi(self, mock_run):
        # Test capturing visible text including ANSI sequences
        mock_run.return_value = "Hello \x1b[31mWorld\x1b[0m!"
        res = tmux_util.capture_pane_visible_text("%0", last_lines=100, include_ansi=True)
        
        mock_run.assert_called_once_with(["capture-pane", "-p", "-J", "-t", "%0", "-S", "-100"])
        self.assertEqual(res, "Hello \x1b[31mWorld\x1b[0m!")

    @mock.patch("tmux_util.run_tmux_cmd")
    def test_is_pane_in_copy_mode_true(self, mock_run):
        mock_run.return_value = "1"
        self.assertTrue(tmux_util.is_pane_in_copy_mode("%0"))
        mock_run.assert_called_once_with(["display-message", "-p", "-t", "%0", "#{pane_in_mode}"])

    @mock.patch("tmux_util.run_tmux_cmd")
    def test_is_pane_in_copy_mode_false(self, mock_run):
        mock_run.return_value = "0"
        self.assertFalse(tmux_util.is_pane_in_copy_mode("%0"))
        mock_run.assert_called_once_with(["display-message", "-p", "-t", "%0", "#{pane_in_mode}"])

    @mock.patch("tmux_util.subprocess.run")
    def test_spin_agent_clears_inherited_agent_identity(self, run):
        inherited_env = {
            "AGENT_ID": "parent-id",
            "AGENT_NAME": "parent-name",
            "AGENT_UUID": "parent-uuid",
            "PATH": "/bin",
        }
        run.return_value = mock.Mock(returncode=0, stdout="%1\n")
        with mock.patch.dict("os.environ", inherited_env, clear=True):
            tmux_util.spin_agent("child-agent", "pi", target_pane="%1", tmux_socket="/tmp/tmux.sock")

        cmd = run.call_args_list[0].args[0]
        self.assertEqual(cmd[:4], ["tmux", "-S", "/tmp/tmux.sock", "split-window"])
        self.assertIn("-e", cmd)
        self.assertIn("SUGGESTED_AGENT_NAME=child-agent", cmd)
        self.assertEqual(cmd[-1], "unset AGENT_ID AGENT_NAME AGENT_UUID; export SUGGESTED_AGENT_NAME=child-agent; exec pi")
        child_env = run.call_args_list[0].kwargs["env"]
        self.assertNotIn("AGENT_ID", child_env)
        self.assertNotIn("AGENT_NAME", child_env)
        self.assertNotIn("AGENT_UUID", child_env)
        self.assertEqual(child_env["SUGGESTED_AGENT_NAME"], "child-agent")

    @mock.patch("tmux_util.subprocess.run")
    def test_spin_agent_preserves_command_args(self, run):
        run.return_value = mock.Mock(returncode=0, stdout="%1\n")
        with mock.patch.dict("os.environ", {}, clear=True):
            tmux_util.spin_agent("child-agent", "pi --some-flag 'two words'")

        cmd = run.call_args.args[0]
        self.assertEqual(
            cmd[-1],
            "unset AGENT_ID AGENT_NAME AGENT_UUID; export SUGGESTED_AGENT_NAME=child-agent; exec pi --some-flag 'two words'",
        )

    @mock.patch("tmux_util.run_tmux_cmd")
    def test_send_literal_text_uses_literal_mode_and_submit(self, mock_run):
        tmux_util.send_literal_text("%1", "hello; $USER", submit=True, socket_path="sock")

        self.assertEqual(mock_run.call_args_list[0].args[0], ["-S", "sock", "send-keys", "-t", "%1", "-l", "--", "hello; $USER"])
        self.assertEqual(mock_run.call_args_list[1].args[0], ["-S", "sock", "send-keys", "-t", "%1", "Enter"])

    @mock.patch("tmux_util.run_tmux_cmd")
    def test_send_literal_text_can_skip_submit(self, mock_run):
        tmux_util.send_literal_text("%1", "draft", submit=False)

        mock_run.assert_called_once_with(["send-keys", "-t", "%1", "-l", "--", "draft"])

    @mock.patch("tmux_util.run_tmux_cmd")
    def test_send_literal_text_starting_with_dash_uses_option_separator(self, mock_run):
        tmux_util.send_literal_text("%1", "-n", submit=False)

        mock_run.assert_called_once_with(["send-keys", "-t", "%1", "-l", "--", "-n"])

    @mock.patch("tmux_util.run_tmux_cmd")
    def test_send_symbolic_keys_normalizes_aliases(self, mock_run):
        normalized = tmux_util.send_symbolic_keys("%1", ["ESC", "ENTER", "C-C"], socket_path="sock")

        self.assertEqual(normalized, ["Escape", "Enter", "C-c"])
        mock_run.assert_called_once_with(["-S", "sock", "send-keys", "-t", "%1", "Escape", "Enter", "C-c"])

    def test_send_symbolic_keys_rejects_unsafe_tokens(self):
        with self.assertRaises(ValueError):
            tmux_util.normalize_tmux_key_tokens(["Enter; display-message pwned"])
        with self.assertRaises(ValueError):
            tmux_util.normalize_tmux_key_tokens(["C-Not-A-Modifier"])
        with self.assertRaises(ValueError):
            tmux_util.normalize_tmux_key_tokens([" Enter"])
        with self.assertRaises(ValueError):
            tmux_util.normalize_tmux_key_tokens(["C-"])


if __name__ == "__main__":
    unittest.main()
