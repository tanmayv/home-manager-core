import json
import os
import unittest
from unittest import mock

import registry_client


class TestRegistryClientRouting(unittest.TestCase):
    def test_unqualified_send_uses_single_json_configured_registry(self):
        client = registry_client.RegistryClient("r1", "https://r1.example")
        sent = []
        def fake_send(*args):
            sent.append(args)
            return 202, {"sent_by": "r1"}
        with mock.patch.object(registry_client, "load_registry_clients", return_value=[client]), \
             mock.patch.object(client, "send_remote_message", fake_send):
            status, body = registry_client.send_remote_message("sender", "s1", "t1", "host1", "agent1", "hello")
        self.assertEqual((status, body), (202, {"sent_by": "r1"}))
        self.assertEqual(sent, [("sender", "s1", "t1", "host1", "agent1", "hello", None, None)])

    def test_unqualified_send_routes_to_single_matching_registry(self):
        clients = [
            registry_client.RegistryClient("r1", "https://r1.example"),
            registry_client.RegistryClient("r2", "https://r2.example"),
        ]
        def fake_request(self, method, path, payload=None, timeout=3):
            if path == "/agents":
                agents = [] if self.name == "r1" else [{"hostname": "host2", "name": "agent2", "agent_id": "a2"}]
                return 200, {"agents": agents}
            return 202, {"sent_by": self.name}
        with mock.patch.object(registry_client, "load_registry_clients", return_value=clients), \
             mock.patch.object(registry_client.RegistryClient, "request", fake_request):
            status, body = registry_client.send_remote_message("sender", "s1", "t1", "host2", "agent2", "hello")
        self.assertEqual((status, body), (202, {"sent_by": "r2"}))

    def test_unqualified_send_errors_when_hostname_is_ambiguous(self):
        clients = [
            registry_client.RegistryClient("r1", "https://r1.example"),
            registry_client.RegistryClient("r2", "https://r2.example"),
        ]
        def fake_request(self, method, path, payload=None, timeout=3):
            if path == "/agents":
                return 200, {"agents": [{"hostname": "shared", "name": "agent", "agent_id": self.name}]}
            return 202, {}
        with mock.patch.object(registry_client, "load_registry_clients", return_value=clients), \
             mock.patch.object(registry_client.RegistryClient, "request", fake_request):
            status, body = registry_client.send_remote_message("sender", "s1", "t1", "shared", "agent", "hello")
        self.assertEqual(status, 409)
        self.assertIn("Ambiguous", body["message"])
        self.assertIn("r1:shared/agent", body["message"])

    def test_send_remote_pane_input_posts_to_pane_inputs(self):
        client = registry_client.RegistryClient("r1", "https://r1.example")
        seen = []
        def fake_request(method, path, payload=None, timeout=3):
            seen.append((method, path, payload))
            return 202, {"queued": True}
        with mock.patch.object(registry_client, "load_registry_clients", return_value=[client]), \
             mock.patch.object(client, "request", fake_request):
            status, body = registry_client.send_remote_pane_input("sender", "s1", "t1", "host1", "agent1", "text", text="hello", submit=False)
        self.assertEqual((status, body), (202, {"queued": True}))
        self.assertEqual(seen, [("POST", "/pane-inputs", {
            "sender_agent_id": "s1",
            "sender_agent_name": "sender",
            "sender_tracker_id": "t1",
            "input_type": "text",
            "text": "hello",
            "submit": False,
            "target_agent_name": "agent1",
            "target_hostname": "host1",
        })])

    def test_send_remote_pane_input_routes_to_matching_registry(self):
        clients = [
            registry_client.RegistryClient("r1", "https://r1.example"),
            registry_client.RegistryClient("r2", "https://r2.example"),
        ]
        def fake_request(self, method, path, payload=None, timeout=3):
            if path == "/agents":
                agents = [] if self.name == "r1" else [{"hostname": "host2", "name": "agent2", "agent_id": "a2"}]
                return 200, {"agents": agents}
            return 202, {"sent_by": self.name, "payload": payload}
        with mock.patch.object(registry_client, "load_registry_clients", return_value=clients), \
             mock.patch.object(registry_client.RegistryClient, "request", fake_request):
            status, body = registry_client.send_remote_pane_input("sender", "s1", "t1", "host2", "123e4567-e89b-12d3-a456-426614174000", "keys", keys=["Enter"])
        self.assertEqual(status, 202)
        self.assertEqual(body["sent_by"], "r2")
        self.assertEqual(body["payload"]["target_agent_id"], "123e4567-e89b-12d3-a456-426614174000")
        self.assertEqual(body["payload"]["keys"], ["Enter"])

    def test_send_remote_pane_input_to_explicit_registry(self):
        client = registry_client.RegistryClient("corp", "https://corp.example")
        with mock.patch.object(registry_client, "load_registry_clients", return_value=[client]), \
             mock.patch.object(client, "request", return_value=(202, {"queued": True})) as req:
            status, body = registry_client.send_remote_pane_input_to_registry("corp", "sender", "s1", "t1", "host", "agent", "keys", keys=["C-c"])
        self.assertEqual((status, body), (202, {"queued": True}))
        self.assertEqual(req.call_args.args[0:2], ("POST", "/pane-inputs"))
        self.assertEqual(req.call_args.args[2]["keys"], ["C-c"])


if __name__ == "__main__":
    unittest.main()
