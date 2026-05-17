import json, logging, os, socket, threading, time, urllib.error, urllib.request, uuid
import state

REGISTRY_URL = os.environ.get("AGENT_REGISTRY_URL", "").rstrip("/")
TOKEN = os.environ.get("AGENT_REGISTRY_TOKEN", "")
HOSTNAME = os.environ.get("AGENT_TRACKER_HOSTNAME", socket.gethostname())
TRACKER_ID = os.environ.get("AGENT_TRACKER_ID", str(uuid.uuid5(uuid.NAMESPACE_DNS, HOSTNAME)))
HTTP_PORT = int(os.environ.get("AGENT_TRACKER_HTTP_PORT", "19876"))
HEARTBEAT_INTERVAL = int(os.environ.get("AGENT_REGISTRY_HEARTBEAT_SECONDS", "30"))


def _post(path, payload):
    if not REGISTRY_URL: return None
    req = urllib.request.Request(f"{REGISTRY_URL}{path}", data=json.dumps(payload).encode(), headers={"Content-Type": "application/json", **({"Authorization": f"Bearer {TOKEN}"} if TOKEN else {})}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=3) as resp: return resp.status
    except urllib.error.HTTPError as e: return e.code
    except Exception as e:
        logging.debug(f"registry request failed for {path}: {e}"); return None


def register():
    return _post("/trackers", {"tracker_id": TRACKER_ID, "hostname": HOSTNAME, "address": os.environ.get("AGENT_TRACKER_ADDRESS", HOSTNAME), "http_port": HTTP_PORT, "agents": state.get_agents_for_registry()})

def heartbeat(): return _post(f"/trackers/{TRACKER_ID}/heartbeat", {"agents": state.get_agents_for_registry()})

def push_agent_update(agent_id, status):
    if REGISTRY_URL: threading.Thread(target=lambda: _post(f"/trackers/{TRACKER_ID}/agent-update", {"agent_id": agent_id, "status": status}), daemon=True).start()


def background_sync():
    if not REGISTRY_URL: return
    register()
    while True:
        if heartbeat() == 404: register()
        time.sleep(HEARTBEAT_INTERVAL)
