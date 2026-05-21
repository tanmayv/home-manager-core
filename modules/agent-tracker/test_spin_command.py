import importlib.util
import os
import tempfile
import unittest
from unittest import mock

_CTL_PATH = os.path.join(os.path.dirname(__file__), "agent-tracker-ctl.py")
_spec = importlib.util.spec_from_file_location("agent_tracker_ctl", _CTL_PATH)
ctl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ctl)

import tmux_util


class TestSpinCommand(unittest.TestCase):
    def test_spin_session_name_uses_directory_leaf(self):
        self.assertEqual(ctl.spin_session_name("/tmp/my-project"), "my-project")
        self.assertEqual(ctl.spin_session_name("/tmp/a:b"), "a_b")
        self.assertEqual(ctl.spin_session_name("/tmp/spin-bug.test"), "spin-bug_test")

    def test_spin_subcommand_sends_directory_session_and_command(self):
        with tempfile.TemporaryDirectory() as tmp, \
             mock.patch.object(ctl, "ensure_tracker_running", return_value=True), \
             mock.patch.dict(os.environ, {"PATH": "/mock/path"}), \
             mock.patch("ctl_commands.spin.call_rpc", return_value="proj") as call_rpc, \
             mock.patch.object(ctl.sys, "argv", ["agent-tracker-ctl", "spin", tmp, "gemini", "--model", "flash"]):
            ctl.main()
        call_rpc.assert_called_once()
        method, params = call_rpc.call_args.args
        self.assertEqual(method, "spin_agent")
        self.assertEqual(params["directory"], tmp)
        self.assertEqual(params["session"], os.path.basename(tmp))
        self.assertEqual(params["name"], os.path.basename(tmp))
        self.assertEqual(params["command"], "bash -c 'export PATH=/mock/path; gemini --model flash; zsh'")

    def test_spin_subcommand_with_no_fallback_sends_raw_command(self):
        with tempfile.TemporaryDirectory() as tmp, \
             mock.patch.object(ctl, "ensure_tracker_running", return_value=True), \
             mock.patch("ctl_commands.spin.call_rpc", return_value="proj") as call_rpc, \
             mock.patch.object(ctl.sys, "argv", ["agent-tracker-ctl", "spin", "--no-fallback", tmp, "gemini", "--model", "flash"]):
            ctl.main()
        call_rpc.assert_called_once()
        method, params = call_rpc.call_args.args
        self.assertEqual(method, "spin_agent")
        self.assertEqual(params["command"], "gemini --model flash")

    def test_tmux_spin_creates_new_session_for_missing_session(self):
        calls = []

        def fake_run(cmd, **kwargs):
            calls.append(cmd)
            if cmd[:2] == ["tmux", "has-session"]:
                return mock.Mock(returncode=1)
            if cmd[:2] == ["tmux", "new-session"]:
                return mock.Mock(returncode=0, stdout="%9\n")
            if cmd[:2] == ["tmux", "switch-client"]:
                return mock.Mock(returncode=0, stdout="")
            return mock.Mock(returncode=0, stdout="")

        with mock.patch.object(tmux_util.subprocess, "run", fake_run):
            pane_id = tmux_util.spin_agent("proj", "gemini --model flash", session="proj", directory="/tmp/proj")

        self.assertEqual(pane_id, "%9")
        self.assertIn(["tmux", "has-session", "-t", "proj"], calls)
        self.assertTrue(any(cmd == ["tmux", "new-session", "-d", "-P", "-F", "#{pane_id}", "-s", "proj", "-c", "/tmp/proj", "gemini --model flash"] for cmd in calls))
        self.assertTrue(any(cmd == ["tmux", "switch-client", "-t", "proj"] for cmd in calls))
        self.assertFalse(any(cmd[:2] == ["tmux", "send-keys"] for cmd in calls))

    def test_tmux_spin_opens_window_for_existing_session(self):
        calls = []

        def fake_run(cmd, **kwargs):
            calls.append(cmd)
            if cmd[:2] == ["tmux", "has-session"]:
                return mock.Mock(returncode=0)
            if cmd[:2] == ["tmux", "new-window"]:
                return mock.Mock(returncode=0, stdout="%10\n")
            if cmd[:2] == ["tmux", "switch-client"]:
                return mock.Mock(returncode=0, stdout="")
            return mock.Mock(returncode=0, stdout="")

        with mock.patch.object(tmux_util.subprocess, "run", fake_run):
            pane_id = tmux_util.spin_agent("proj", "gemini", session="proj", directory="/tmp/proj")

        self.assertEqual(pane_id, "%10")
        self.assertTrue(any(cmd == ["tmux", "new-window", "-P", "-F", "#{pane_id}", "-t", "proj", "-c", "/tmp/proj", "gemini"] for cmd in calls))
        self.assertTrue(any(cmd == ["tmux", "switch-client", "-t", "proj"] for cmd in calls))
        self.assertFalse(any(cmd[:2] == ["tmux", "send-keys"] for cmd in calls))

    def test_tmux_spin_forwards_environment_variables(self):
        calls = []

        def fake_run(cmd, **kwargs):
            calls.append(cmd)
            if cmd[:2] == ["tmux", "has-session"]:
                return mock.Mock(returncode=0)
            if cmd[:2] == ["tmux", "new-window"]:
                return mock.Mock(returncode=0, stdout="%11\n")
            return mock.Mock(returncode=0, stdout="")

        with mock.patch.object(tmux_util.subprocess, "run", fake_run):
            tmux_util.spin_agent("proj", "gemini", session="proj", directory="/tmp/proj", env={"PATH": "/my/custom/path"})

        self.assertTrue(any(cmd == ["tmux", "new-window", "-P", "-F", "#{pane_id}", "-t", "proj", "-c", "/tmp/proj", "-e", "PATH=/my/custom/path", "gemini"] for cmd in calls))


if __name__ == "__main__":
    unittest.main()
