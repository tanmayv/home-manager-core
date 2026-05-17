import base64, binascii, json, os, time, urllib.error, urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

TOKEN = os.environ.get("AGENT_REGISTRY_TOKEN", "")
AUTH_REQUIRED = os.environ.get("AGENT_REGISTRY_AUTH", "true").lower() not in ("0", "false", "no")
MAX_BODY_BYTES = int(os.environ.get("AGENT_MAX_DELIVERY_BYTES", "5242880"))
STALE = int(os.environ.get("TRACKER_STALE_SECONDS", "60"))
GONE = int(os.environ.get("TRACKER_GONE_SECONDS", "180"))

class Store:
    def __init__(self): self.trackers, self.agents = {}, {}
    def sweep(self, now=None):
        now = time.time() if now is None else now
        for t in self.trackers.values():
            age = now - t["last_heartbeat"]
            t["status"] = "active" if age <= STALE else "stale" if age <= GONE else "gone"
        self.agents = {k: v for k, v in self.agents.items() if self.trackers.get(v["tracker_id"], {}).get("status") != "gone"}
    def put_tracker(self, body):
        existing = next((tid for tid, t in self.trackers.items() if t["hostname"] == body["hostname"] and tid != body["tracker_id"]), None)
        if existing:
            self.trackers.pop(existing, None); self.agents = {k: v for k, v in self.agents.items() if v["tracker_id"] != existing}
        created = body["tracker_id"] not in self.trackers
        self.trackers[body["tracker_id"]] = {"tracker_id": body["tracker_id"], "hostname": body["hostname"], "address": body["address"], "http_port": body["http_port"], "last_heartbeat": time.time(), "status": "active"}
        self.replace_agents(body["tracker_id"], body.get("agents", [])); return created
    def replace_agents(self, tracker_id, agents):
        t, now = self.trackers[tracker_id], time.time()
        self.agents = {k: v for k, v in self.agents.items() if v["tracker_id"] != tracker_id}
        for a in agents: self.agents[a["agent_id"]] = {**a, "tracker_id": tracker_id, "hostname": t["hostname"], "last_seen": now, "address": t["address"], "http_port": t["http_port"]}
    def update_agent(self, tracker_id, agent_id, status):
        a = self.agents.get(agent_id)
        if not a: return 404
        if a["tracker_id"] != tracker_id: return 403
        a["status"], a["last_seen"] = status, time.time(); return 200

def make_handler(store=None, token=None, auth_required=None):
    store, token = store or Store(), TOKEN if token is None else token
    auth_required = AUTH_REQUIRED if auth_required is None else auth_required
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args): return
        def _json(self, code, payload):
            self.send_response(code); self.send_header("Content-Type", "application/json"); self.end_headers(); self.wfile.write(json.dumps(payload).encode())
        def _parts(self): return [p for p in urlparse(self.path).path.split("/") if p]
        def _body(self):
            length = int(self.headers.get("Content-Length", "0") or 0)
            if length > MAX_BODY_BYTES: return "__too_large__"
            try: return json.loads(self.rfile.read(length) or b"{}")
            except json.JSONDecodeError: return None
        def _check(self):
            store.sweep()
            if self.path == "/healthz": return True
            if (not auth_required) or (token and self.headers.get("Authorization") == f"Bearer {token}"): return True
            self._json(401, {"error": "unauthorized", "message": "invalid or missing token"}); return False
        def do_GET(self):
            if not self._check(): return
            if self.path == "/healthz": return self._json(200, {"ok": True})
            parts, q, agents = self._parts(), parse_qs(urlparse(self.path).query), list(store.agents.values())
            if parts == ["agents"]:
                for key in ("name", "hostname", "status"):
                    if q.get(key): agents = [a for a in agents if a.get(key) == q[key][0]]
                agents = [{k: a[k] for k in ("agent_id", "name", "aliases", "tracker_id", "hostname", "status", "agent_type", "agent_cmd", "last_seen")} for a in agents]
                return self._json(200, {"agents": agents})
            if len(parts) == 2 and parts[0] == "agents":
                agent = store.agents.get(parts[1])
                return self._json(200, agent) if agent else self._json(404, {"error": "agent_not_found", "message": "no agent with that ID is registered"})
            self._json(404, {"error": "not_found", "message": "no such endpoint"})
        def do_POST(self):
            if not self._check(): return
            parts, body = self._parts(), self._body()
            if body == "__too_large__": return self._json(413, {"error": "payload_too_large", "message": "request body exceeds limit"})
            if body is None: return self._json(400, {"error": "invalid_request", "message": "malformed JSON body"})
            if parts == ["trackers"]:
                if not {"tracker_id", "hostname", "address", "http_port"}.issubset(body): return self._json(400, {"error": "invalid_request", "message": "tracker_id, hostname, address, http_port are required"})
                return self._json(201 if store.put_tracker(body) else 200, {"tracker_id": body["tracker_id"]})
            if len(parts) == 3 and parts[0] == "trackers" and parts[2] in {"heartbeat", "agent-update"}:
                if parts[1] not in store.trackers: return self._json(404, {"error": "tracker_not_found", "message": "tracker not registered; call POST /trackers first"})
                if parts[2] == "heartbeat": store.trackers[parts[1]]["last_heartbeat"] = time.time(); store.replace_agents(parts[1], body.get("agents", [])); return self._json(200, {"ok": True})
                if not {"agent_id", "status"}.issubset(body): return self._json(400, {"error": "invalid_request", "message": "agent_id and status are required"})
                code = store.update_agent(parts[1], body["agent_id"], body["status"])
                if code == 200: return self._json(200, {"ok": True})
                if code == 403: return self._json(403, {"error": "wrong_tracker", "message": "agent does not belong to this tracker"})
                return self._json(404, {"error": "agent_not_found", "message": "agent not in registry cache; wait for next heartbeat"})
            if parts == ["messages"]:
                if not body.get("message") and not body.get("attachments"): return self._json(400, {"error": "invalid_request", "message": "message text or attachments are required"})
                if body.get("attachments"):
                    seen_names = set()
                    for att in body["attachments"]:
                        safe_name = os.path.basename(att.get("name") or "")
                        if not safe_name or "content_b64" not in att:
                            return self._json(400, {"error": "invalid_request", "message": "invalid attachments"})
                        if safe_name in seen_names:
                            return self._json(400, {"error": "invalid_request", "message": "duplicate attachment name"})
                        seen_names.add(safe_name)
                        try:
                            base64.b64decode(att["content_b64"], validate=True)
                        except (binascii.Error, ValueError):
                            return self._json(400, {"error": "invalid_request", "message": "invalid attachment payload"})
                target = store.agents.get(body.get("target_agent_id")) if body.get("target_agent_id") else None
                if not target and body.get("target_agent_name"):
                    if not body.get("target_hostname"): return self._json(400, {"error": "hostname_required", "message": "target_hostname is required when using target_agent_name; bare-name global resolution is not supported"})
                    target = next((a for a in store.agents.values() if a["hostname"] == body["target_hostname"] and (a["name"] == body["target_agent_name"] or body["target_agent_name"] in a.get("aliases", []))), None)
                if not target:
                    if body.get("target_agent_name") or body.get("target_agent_id"): return self._json(404, {"error": "agent_not_found", "message": "no agent with that ID or name is registered on the specified tracker"})
                    return self._json(400, {"error": "missing_target", "message": "provide target_agent_id or target_agent_name"})
                if body.get("sender_tracker_id") == target["tracker_id"]: return self._json(400, {"error": "same_tracker", "message": "target agent is on the same tracker; use local send"})
                tracker = store.trackers.get(target["tracker_id"], {})
                if tracker.get("status") != "active": return self._json(503, {"error": "tracker_offline", "message": "target tracker is stale or gone", "tracker_status": tracker.get("status", "gone")})
                req = urllib.request.Request(
                    f"http://{tracker['address']}:{tracker['http_port']}/deliver",
                    data=json.dumps({"target_agent_id": target["agent_id"], "sender_name": body.get("sender_agent_name", "unknown"), "sender_agent_id": body.get("sender_agent_id"), "sender_tracker": store.trackers.get(body.get("sender_tracker_id"), {}).get("hostname", body.get("sender_tracker_id")), "message": body.get("message"), "attachments": body.get("attachments"), "sent_at": time.strftime("%Y-%m-%dT%H:%M:%S+00:00", time.gmtime())}).encode(),
                    headers={"Content-Type": "application/json", **({"Authorization": f"Bearer {token}"} if token else {})},
                    method="POST",
                )
                try:
                    with urllib.request.urlopen(req, timeout=3):
                        return self._json(202, {"ok": True, "target_agent_id": target["agent_id"], "target_name": target["name"], "target_tracker": target["hostname"]})
                except urllib.error.HTTPError as e:
                    try:
                        err = json.loads(e.read().decode())
                        detail = err.get("message", str(e))
                        if e.code == 400:
                            return self._json(400, {"error": err.get("error", "invalid_request"), "message": detail})
                    except Exception:
                        detail = str(e)
                    return self._json(503, {"error": "delivery_failed", "message": f"target tracker returned an error: {detail}"})
                except Exception as e:
                    return self._json(503, {"error": "tracker_unreachable", "message": f"could not connect to target tracker: {e}"})
            self._json(404, {"error": "not_found", "message": "no such endpoint"})
    return Handler

def serve_forever():
    ThreadingHTTPServer(("0.0.0.0", int(os.environ.get("AGENT_REGISTRY_PORT", "8080"))), make_handler()).serve_forever()

if __name__ == "__main__": serve_forever()
