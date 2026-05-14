import unittest

import monitor


class TestMonitor(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
