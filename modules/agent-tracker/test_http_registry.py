import importlib.util
import json
import os
import threading
import time
import unittest
import urllib.error
import unittest.mock as mock
import urllib.request
from http.server import ThreadingHTTPServer

import http_sidecar
import registry_client
import state

_REGISTRY_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "agent-registry", "server.py")
_spec = importlib.util.spec_from_file_location("agent_registry_server", _REGISTRY_PATH)
registry_server = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(registry_server)


def start(handler):
    server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server, f"http://127.0.0.1:{server.server_port}"


def get(url, token=None):
    req = urllib.request.Request(url, headers=({"Authorization": f"Bearer {token}"} if token else {}))
    with urllib.request.urlopen(req, timeout=2) as resp:
        return resp.status, json.loads(resp.read().decode())


def post(url, body, token=None):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json", **({"Authorization": f"Bearer {token}"} if token else {})}, method="POST")
    with urllib.request.urlopen(req, timeout=2) as resp:
        return resp.status, json.loads(resp.read().decode())


class TestHttpAndRegistry(unittest.TestCase):
    def setUp(self):
        state.state = {}
        state.name_index = {}
        state.pane_index = {}
        state.INBOX_DIR = "/tmp/test-agent-http-inboxes"

    def test_sidecar_requires_auth_and_returns_snapshot(self):
        state.set_agent("agent1", {"agent_id": "id-1", "status": "idle", "tmux_pane": "%1"})
        server, base = start(http_sidecar.make_handler(token="secret"))
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            get(f"{base}/agents")
        self.assertEqual(ctx.exception.code, 401)
        self.assertEqual(get(f"{base}/healthz"), (200, {"ok": True}))
        code, body = get(f"{base}/agents", token="secret")
        self.assertEqual(code, 200)
        self.assertEqual(body["agents"][0]["agent_id"], "id-1")
        self.assertNotIn("tmux_pane", body["agents"][0])

    def test_sidecar_allows_open_access_when_auth_disabled(self):
        state.set_agent("agent1", {"agent_id": "id-1", "status": "idle"})
        server, base = start(http_sidecar.make_handler(auth_required=False))
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        self.assertEqual(get(f"{base}/agents")[1]["agents"][0]["agent_id"], "id-1")

    def test_sidecar_deliver_requires_auth_and_writes_inbox(self):
        inbox_path = os.path.join(state.INBOX_DIR, "id-1.inbox")
        if os.path.exists(inbox_path):
            os.remove(inbox_path)
        state.set_agent("agent1", {"agent_id": "id-1", "status": "idle", "tmux_pane": "%1", "tmux_socket": "sock"})
        server, base = start(http_sidecar.make_handler(token="secret"))
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            post(f"{base}/deliver", {"target_agent_id": "id-1", "message": "hello"})
        self.assertEqual(ctx.exception.code, 401)
        with mock.patch("tmux_util.send_keys") as send_keys:
            self.assertEqual(post(f"{base}/deliver", {"target_agent_id": "id-1", "sender_name": "alice", "sender_tracker": "host2", "message": "hello"}, token="secret")[0], 200)
            send_keys.assert_called_once()
        with open(inbox_path, "r") as f:
            self.assertIn("alice (via host2)", f.read())

    def test_sidecar_deliver_rejects_invalid_attachment_payload_and_duplicate_names(self):
        state.set_agent("agent1", {"agent_id": "id-1", "status": "idle", "tmux_pane": "%1", "tmux_socket": "sock"})
        server, base = start(http_sidecar.make_handler(auth_required=False))
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        attach_root = os.path.join(state.INBOX_DIR, "attachments", "id-1")
        bad = {"target_agent_id": "id-1", "attachments": [{"name": "a.txt", "content_b64": "%%%"}]}
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            post(f"{base}/deliver", bad)
        self.assertEqual(ctx.exception.code, 400)
        self.assertEqual(sum(len(files) for _, _, files in os.walk(attach_root)) if os.path.exists(attach_root) else 0, 0)
        dup = {"target_agent_id": "id-1", "attachments": [{"name": "a.txt", "content_b64": "aGVsbG8="}, {"name": "a.txt", "content_b64": "aGVsbG8="}]}
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            post(f"{base}/deliver", dup)
        self.assertEqual(ctx.exception.code, 400)
        self.assertEqual(sum(len(files) for _, _, files in os.walk(attach_root)) if os.path.exists(attach_root) else 0, 0)

    def test_registry_register_heartbeat_update_and_gone_sweep(self):
        store = registry_server.Store()
        server, base = start(registry_server.make_handler(store=store, token="secret"))
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        payload = {"tracker_id": "t1", "hostname": "host1", "address": "127.0.0.1", "http_port": 19876, "agents": [{"agent_id": "a1", "name": "agent1", "aliases": [], "status": "idle", "agent_type": "pi", "agent_cmd": "pi"}]}
        self.assertEqual(post(f"{base}/trackers", payload, token="secret")[0], 201)
        self.assertEqual(post(f"{base}/trackers/t1/agent-update", {"agent_id": "a1", "status": "working"}, token="secret")[0], 200)
        code, body = get(f"{base}/agents/a1", token="secret")
        self.assertEqual((code, body["status"], body["hostname"]), (200, "working", "host1"))
        agents = get(f"{base}/agents", token="secret")[1]["agents"]
        self.assertIn("address", body)
        self.assertNotIn("address", agents[0])
        self.assertNotIn("http_port", agents[0])
        self.assertEqual(post(f"{base}/trackers/t1/heartbeat", {"agents": payload["agents"]}, token="secret")[0], 200)
        old_stale, old_gone = registry_server.STALE, registry_server.GONE
        registry_server.STALE, registry_server.GONE = 1, 2
        self.addCleanup(setattr, registry_server, "STALE", old_stale)
        self.addCleanup(setattr, registry_server, "GONE", old_gone)
        store.trackers["t1"]["last_heartbeat"] = time.time() - 5
        self.assertEqual(get(f"{base}/agents", token="secret")[1]["agents"], [])

    def test_registry_allows_open_access_when_auth_disabled(self):
        server, base = start(registry_server.make_handler(auth_required=False))
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        payload = {"tracker_id": "t1", "hostname": "host1", "address": "127.0.0.1", "http_port": 19876, "agents": []}
        self.assertEqual(post(f"{base}/trackers", payload)[0], 201)
        self.assertEqual(get(f"{base}/agents")[0], 200)

    def test_registry_rejects_malformed_json(self):
        server, base = start(registry_server.make_handler(auth_required=False))
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        req = urllib.request.Request(f"{base}/trackers", data=b"{", headers={"Content-Type": "application/json"}, method="POST")
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            urllib.request.urlopen(req, timeout=2)
        self.assertEqual(ctx.exception.code, 400)

    def test_registry_messages_reject_invalid_attachment_payload(self):
        server, base = start(registry_server.make_handler(auth_required=False))
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        payload = {"sender_tracker_id": "t1", "target_agent_id": "a2", "message": "hi", "attachments": [{"name": "bad.txt", "content_b64": "%%%"}]}
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            post(f"{base}/messages", payload)
        self.assertEqual(ctx.exception.code, 400)

    def test_registry_messages_auth_same_tracker_offline_and_happy_path(self):
        old_state = (state.state, state.name_index, state.pane_index)
        self.addCleanup(setattr, state, "state", old_state[0])
        self.addCleanup(setattr, state, "name_index", old_state[1])
        self.addCleanup(setattr, state, "pane_index", old_state[2])
        state.state, state.name_index, state.pane_index = {}, {}, {}
        inbox_path = os.path.join(state.INBOX_DIR, "a2.inbox")
        if os.path.exists(inbox_path):
            os.remove(inbox_path)
        state.set_agent("agent2", {"agent_id": "a2", "status": "idle", "tmux_pane": "%2", "tmux_socket": "sock"})
        sidecar, sidecar_base = start(http_sidecar.make_handler(auth_required=False))
        self.addCleanup(sidecar.server_close)
        self.addCleanup(sidecar.shutdown)
        store = registry_server.Store()
        source = {"tracker_id": "t1", "hostname": "host1", "address": "127.0.0.1", "http_port": 19875, "agents": [{"agent_id": "a1", "name": "agent1", "aliases": [], "status": "idle", "agent_type": "pi", "agent_cmd": "pi"}]}
        target = {"tracker_id": "t2", "hostname": "host2", "address": "127.0.0.1", "http_port": int(sidecar_base.rsplit(":", 1)[1]), "agents": [{"agent_id": "a2", "name": "agent2", "aliases": [], "status": "idle", "agent_type": "pi", "agent_cmd": "pi"}]}
        store.put_tracker(source); store.put_tracker(target)
        server, base = start(registry_server.make_handler(store=store, token="secret"))
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            post(f"{base}/messages", {"sender_tracker_id": "t1", "target_agent_id": "a2", "message": "hi"})
        self.assertEqual(ctx.exception.code, 401)
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            post(f"{base}/messages", {"sender_tracker_id": "t2", "target_agent_id": "a2", "message": "hi"}, token="secret")
        self.assertEqual(ctx.exception.code, 400)
        store.trackers["t2"]["last_heartbeat"] = time.time() - 100
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            post(f"{base}/messages", {"sender_tracker_id": "t1", "target_agent_id": "a2", "message": "hi"}, token="secret")
        self.assertEqual(ctx.exception.code, 503)
        store.trackers["t2"]["last_heartbeat"] = time.time()
        long_message = "x" * 65536
        attachment = {"name": "note.txt", "content_b64": "aGVsbG8=", "content_type": "text/plain"}
        with mock.patch("tmux_util.send_keys"):
            self.assertEqual(post(f"{base}/messages", {"sender_tracker_id": "t1", "sender_agent_name": "agent1", "target_agent_id": "a2", "message": long_message, "attachments": [attachment]}, token="secret")[0], 202)
        with open(inbox_path, "r") as f:
            saved = json.loads(f.readline())
        self.assertEqual(saved["message"], long_message)
        self.assertEqual(saved["attachments"][0]["name"], "note.txt")
        self.assertTrue(os.path.exists(saved["attachments"][0]["path"]))

    def test_registry_client_reregisters_on_heartbeat_404(self):
        with mock.patch.object(registry_client, "REGISTRY_URL", "http://x"), \
             mock.patch.object(registry_client, "register") as register, \
             mock.patch.object(registry_client, "heartbeat", side_effect=[404]), \
             mock.patch.object(registry_client.time, "sleep", side_effect=SystemExit):
            with self.assertRaises(SystemExit):
                registry_client.background_sync()
        self.assertEqual(register.call_count, 2)


if __name__ == "__main__":
    unittest.main()
