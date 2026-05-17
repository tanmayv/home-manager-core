import json, os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import state

AUTH_REQUIRED = os.environ.get("AGENT_REGISTRY_AUTH", "true").lower() not in ("0", "false", "no")

def make_handler(snapshot_fn=state.get_agents_for_registry, token=None, auth_required=None):
    token = os.environ.get("AGENT_REGISTRY_TOKEN", "") if token is None else token
    auth_required = AUTH_REQUIRED if auth_required is None else auth_required
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args): return
        def _json(self, code, payload):
            self.send_response(code); self.send_header("Content-Type", "application/json"); self.end_headers(); self.wfile.write(json.dumps(payload).encode())
        def _authorized(self): return (not auth_required) or (bool(token) and self.headers.get("Authorization") == f"Bearer {token}")
        def do_GET(self):
            if self.path == "/healthz": return self._json(200, {"ok": True})
            if not self._authorized(): return self._json(401, {"error": "unauthorized", "message": "invalid or missing token"})
            if self.path == "/agents": return self._json(200, {"agents": snapshot_fn()})
            return self._json(404, {"error": "not_found", "message": "no such endpoint"})
    return Handler

def serve_forever():
    ThreadingHTTPServer(("0.0.0.0", int(os.environ.get("AGENT_TRACKER_HTTP_PORT", "19876"))), make_handler()).serve_forever()
