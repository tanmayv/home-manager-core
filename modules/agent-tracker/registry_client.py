import json, logging, os, socket, threading, time, urllib.error, urllib.request, uuid
import state

LOG = logging.getLogger("agent-tracker.registry")

REGISTRY_URL = os.environ.get("AGENT_REGISTRY_URL", "").rstrip("/")
TOKEN = os.environ.get("AGENT_REGISTRY_TOKEN", "")
HOSTNAME = os.environ.get("AGENT_TRACKER_HOSTNAME", socket.gethostname())
TRACKER_ID = os.environ.get("AGENT_TRACKER_ID", str(uuid.uuid5(uuid.NAMESPACE_DNS, HOSTNAME)))
HTTP_PORT = int(os.environ.get("AGENT_TRACKER_HTTP_PORT", "19876"))
HEARTBEAT_INTERVAL = int(os.environ.get("AGENT_REGISTRY_HEARTBEAT_SECONDS", "30"))
DELIVERY_WAIT_SECONDS = int(os.environ.get("AGENT_REGISTRY_DELIVERY_WAIT_SECONDS", "25"))
DELIVERY_TARGET_GRACE_SECONDS = int(os.environ.get("AGENT_REGISTRY_DELIVERY_TARGET_GRACE_SECONDS", "60"))
STATUS_PATH = os.path.join(state.CACHE_DIR, "registry-status.json")


def _request(method, path, payload=None, timeout=3):
    if not REGISTRY_URL:
        return None, None
    req = urllib.request.Request(
        f"{REGISTRY_URL}{path}",
        data=None if payload is None else json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", **({"Authorization": f"Bearer {TOKEN}"} if TOKEN else {})},
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode()
            return resp.status, json.loads(body) if body else None
    except urllib.error.HTTPError as e:
        try:
            body = json.loads(e.read().decode())
        except Exception:
            body = None
        LOG.warning("registry request %s %s returned HTTP %s body=%s", method, path, e.code, body)
        return e.code, body
    except Exception as e:
        LOG.warning("registry request %s %s failed: %s", method, path, e)
        return None, None


def register():
    status = _request(
        "POST",
        "/trackers",
        {
            "tracker_id": TRACKER_ID,
            "hostname": HOSTNAME,
            "address": os.environ.get("AGENT_TRACKER_ADDRESS", HOSTNAME),
            "http_port": HTTP_PORT,
            "agents": state.get_agents_for_registry(),
        },
    )[0]
    if status in (200, 201):
        LOG.info("registered tracker_id=%s hostname=%s http_port=%s status=%s", TRACKER_ID, HOSTNAME, HTTP_PORT, status)
    else:
        LOG.warning("failed to register tracker_id=%s hostname=%s status=%s", TRACKER_ID, HOSTNAME, status)
    return status


def heartbeat():
    return _request("POST", f"/trackers/{TRACKER_ID}/heartbeat", {"agents": state.get_agents_for_registry()})[0]


def push_agent_update(agent_id, status):
    if REGISTRY_URL:
        threading.Thread(
            target=lambda: _request("POST", f"/trackers/{TRACKER_ID}/agent-update", {"agent_id": agent_id, "status": status}),
            daemon=True,
        ).start()


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


def fetch_deliveries():
    return _request("GET", f"/trackers/{TRACKER_ID}/deliveries?wait={DELIVERY_WAIT_SECONDS}", timeout=DELIVERY_WAIT_SECONDS + 5)


def ack_delivery(message_id):
    status = _request("POST", f"/trackers/{TRACKER_ID}/deliveries/{message_id}/ack", {})[0]
    if status != 200:
        LOG.warning("failed to ack registry delivery message_id=%s tracker_id=%s status=%s", message_id, TRACKER_ID, status)
    return status


def _record_sync_result(status_code, operation):
    now = time.time()
    connected = isinstance(status_code, int) and 200 <= status_code < 300
    payload = {
        "connected": connected,
        "registry_url": REGISTRY_URL or None,
        "tracker_id": TRACKER_ID,
        "hostname": HOSTNAME,
        "last_operation": operation,
        "last_attempt": now,
        "status_code": status_code,
    }
    try:
        with open(STATUS_PATH, "r") as f:
            existing = json.load(f)
    except Exception:
        existing = {}
    if connected:
        payload["last_success"] = now
    elif "last_success" in existing:
        payload["last_success"] = existing["last_success"]
        payload["last_error"] = f"{operation}:{status_code if status_code is not None else 'unreachable'}"
    else:
        payload["last_error"] = f"{operation}:{status_code if status_code is not None else 'unreachable'}"
    try:
        os.makedirs(os.path.dirname(STATUS_PATH), exist_ok=True)
        with open(STATUS_PATH, "w") as f:
            json.dump(payload, f)
    except Exception as e:
        logging.debug(f"failed to write registry status: {e}")


def _heartbeat_loop():
    _record_sync_result(register(), "register")
    while True:
        status = heartbeat()
        if status == 404:
            LOG.warning("registry heartbeat got 404 for tracker_id=%s; re-registering", TRACKER_ID)
            _record_sync_result(register(), "register")
        else:
            if status != 200:
                LOG.warning("registry heartbeat failed for tracker_id=%s status=%s", TRACKER_ID, status)
            _record_sync_result(status, "heartbeat")
        time.sleep(HEARTBEAT_INTERVAL)


def _delivery_loop():
    missing_target_first_seen = {}
    while True:
        status, body = fetch_deliveries()
        if status == 404:
            LOG.warning("registry delivery poll got 404 for tracker_id=%s; re-registering", TRACKER_ID)
            register()
            continue
        if status != 200:
            LOG.warning("registry delivery poll failed for tracker_id=%s status=%s body=%s", TRACKER_ID, status, body)
            time.sleep(2)
            continue
        deliveries = (body or {}).get("deliveries") or []
        if not deliveries:
            continue
        LOG.info("received %s queued registry deliveries for tracker_id=%s", len(deliveries), TRACKER_ID)
        from rpc_handler import deliver_local_message, DeliveryTargetNotFound, DeliveryValidationError
        for delivery in deliveries:
            try:
                deliver_local_message(
                    delivery["target_agent_id"],
                    {
                        "sender": f'{delivery.get("sender_name", "unknown")} (via {delivery.get("sender_tracker", "unknown")})',
                        "timestamp": delivery.get("sent_at"),
                        "message": delivery.get("message"),
                        "attachments": delivery.get("attachments"),
                        "read": False,
                        "message_id": delivery.get("message_id"),
                    },
                )
                ack_status = ack_delivery(delivery["message_id"])
                if ack_status == 200:
                    missing_target_first_seen.pop(delivery.get("message_id"), None)
                    LOG.info("delivered and acked queued registry message_id=%s target_agent_id=%s", delivery["message_id"], delivery["target_agent_id"])
            except DeliveryValidationError as e:
                logging.warning(f"dropping invalid queued registry message {delivery.get('message_id')}: {e}")
                ack_status = ack_delivery(delivery["message_id"])
                if ack_status == 200:
                    missing_target_first_seen.pop(delivery.get("message_id"), None)
                    LOG.info("acked invalid queued registry message_id=%s after local validation failure", delivery["message_id"])
            except DeliveryTargetNotFound as e:
                message_id = delivery.get("message_id")
                now = time.time()
                first_seen = missing_target_first_seen.setdefault(message_id, now)
                age = now - first_seen
                if age >= DELIVERY_TARGET_GRACE_SECONDS:
                    logging.warning(
                        "dropping queued registry message %s after %.1fs target-not-found grace: %s",
                        message_id,
                        age,
                        e,
                    )
                    ack_status = ack_delivery(delivery["message_id"])
                    if ack_status == 200:
                        missing_target_first_seen.pop(message_id, None)
                        LOG.info("acked undeliverable queued registry message_id=%s after target-not-found grace", message_id)
                else:
                    logging.warning(
                        "deferring queued registry message %s for missing target %s (age %.1fs < grace %ss): %s",
                        message_id,
                        delivery.get("target_agent_id"),
                        age,
                        DELIVERY_TARGET_GRACE_SECONDS,
                        e,
                    )
                    time.sleep(2)
            except RuntimeError as e:
                logging.warning(f"transient local delivery failure for queued registry message {delivery.get('message_id')}: {e}")
                time.sleep(2)
            except Exception as e:
                logging.warning(f"unexpected delivery failure for queued registry message {delivery.get('message_id')}: {e}")
                time.sleep(2)


def background_sync():
    if not REGISTRY_URL:
        LOG.info("registry sync disabled: no AGENT_REGISTRY_URL configured")
        return
    LOG.info(
        "starting registry sync tracker_id=%s hostname=%s registry_url=%s heartbeat_interval=%ss delivery_wait=%ss",
        TRACKER_ID,
        HOSTNAME,
        REGISTRY_URL,
        HEARTBEAT_INTERVAL,
        DELIVERY_WAIT_SECONDS,
    )
    threading.Thread(target=_heartbeat_loop, daemon=True).start()
    _delivery_loop()
