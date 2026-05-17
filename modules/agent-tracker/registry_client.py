import json, logging, os, socket, threading, time, urllib.error, urllib.request, uuid
import state

REGISTRY_URL = os.environ.get("AGENT_REGISTRY_URL", "").rstrip("/")
TOKEN = os.environ.get("AGENT_REGISTRY_TOKEN", "")
HOSTNAME = os.environ.get("AGENT_TRACKER_HOSTNAME", socket.gethostname())
TRACKER_ID = os.environ.get("AGENT_TRACKER_ID", str(uuid.uuid5(uuid.NAMESPACE_DNS, HOSTNAME)))
HTTP_PORT = int(os.environ.get("AGENT_TRACKER_HTTP_PORT", "19876"))
HEARTBEAT_INTERVAL = int(os.environ.get("AGENT_REGISTRY_HEARTBEAT_SECONDS", "30"))


def _request(method, path, payload=None):
    if not REGISTRY_URL:
        return None, None
    req = urllib.request.Request(
        f"{REGISTRY_URL}{path}",
        data=None if payload is None else json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", **({"Authorization": f"Bearer {TOKEN}"} if TOKEN else {})},
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=3) as resp:
            body = resp.read().decode()
            return resp.status, json.loads(body) if body else None
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode())
        except Exception:
            return e.code, None
    except Exception as e:
        logging.debug(f"registry request failed for {path}: {e}")
        return None, None


def register():
    return _request("POST", "/trackers", {"tracker_id": TRACKER_ID, "hostname": HOSTNAME, "address": os.environ.get("AGENT_TRACKER_ADDRESS", HOSTNAME), "http_port": HTTP_PORT, "agents": state.get_agents_for_registry()})[0]

def heartbeat(): return _request("POST", f"/trackers/{TRACKER_ID}/heartbeat", {"agents": state.get_agents_for_registry()})[0]

def push_agent_update(agent_id, status):
    if REGISTRY_URL: threading.Thread(target=lambda: _request("POST", f"/trackers/{TRACKER_ID}/agent-update", {"agent_id": agent_id, "status": status}), daemon=True).start()


def send_remote_message(sender_name, sender_agent_id, sender_tracker_id, target_hostname, target_name_or_id, message=None, attachments=None):
    payload = {
        "sender_agent_id": sender_agent_id,
        "sender_agent_name": sender_name,
        "sender_tracker_id": sender_tracker_id,
        "message": message,
    }
    if attachments:
        payload["attachments"] = attachments
    try:
        uuid.UUID(target_name_or_id)
        payload["target_agent_id"] = target_name_or_id
    except (ValueError, TypeError):
        payload["target_agent_name"] = target_name_or_id
        payload["target_hostname"] = target_hostname
    return _request("POST", "/messages", payload)


def background_sync():
    if not REGISTRY_URL: return
    register()
    while True:
        if heartbeat() == 404: register()
        time.sleep(HEARTBEAT_INTERVAL)
