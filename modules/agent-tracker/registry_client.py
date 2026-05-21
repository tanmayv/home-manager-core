import fcntl, json, logging, os, socket, threading, time, urllib.error, urllib.request, uuid, shlex
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


class RegistryClient:
    def __init__(self, name="default", url="", token="", tracker_id=None, hostname=None, http_port=None):
        self.name = name or "default"
        self.url = (url or "").rstrip("/")
        self.token = token or ""
        self.tracker_id = tracker_id or TRACKER_ID
        self.hostname = hostname or HOSTNAME
        self.http_port = HTTP_PORT if http_port is None else int(http_port)

    def request(self, method, path, payload=None, timeout=3):
        if not self.url:
            return None, None
        req = urllib.request.Request(
            f"{self.url}{path}",
            data=None if payload is None else json.dumps(payload).encode(),
            headers={"Content-Type": "application/json", **({"Authorization": f"Bearer {self.token}"} if self.token else {})},
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
            LOG.warning("registry[%s] request %s %s returned HTTP %s body=%s", self.name, method, path, e.code, body)
            return e.code, body
        except Exception as e:
            LOG.warning("registry[%s] request %s %s failed: %s", self.name, method, path, e)
            return None, None

    def register(self):
        return self.request("POST", "/trackers", {
            "tracker_id": self.tracker_id,
            "hostname": self.hostname,
            "address": os.environ.get("AGENT_TRACKER_ADDRESS", self.hostname),
            "http_port": self.http_port,
            "agents": state.get_agents_for_registry(),
            "agent_configs": state.get_local_configs_for_registry(),
        })[0]

    def heartbeat(self):
        return self.request("POST", f"/trackers/{self.tracker_id}/heartbeat", {
            "agents": state.get_agents_for_registry(),
            "agent_configs": state.get_local_configs_for_registry(),
        })[0]

    def fetch_deliveries(self):
        return self.request("GET", f"/trackers/{self.tracker_id}/deliveries?wait={DELIVERY_WAIT_SECONDS}", timeout=DELIVERY_WAIT_SECONDS + 5)

    def ack_delivery(self, message_id):
        return self.request("POST", f"/trackers/{self.tracker_id}/deliveries/{message_id}/ack", {})[0]

    def fetch_events(self):
        return self.request("GET", f"/trackers/{self.tracker_id}/events?wait={DELIVERY_WAIT_SECONDS}", timeout=DELIVERY_WAIT_SECONDS + 5)

    def ack_event(self, event_id):
        return self.request("POST", f"/trackers/{self.tracker_id}/events/{event_id}/ack", {})[0]

    def publish_event(self, target_tracker_id, event_type, payload):
        return self.request("POST", "/tracker-events", {"event_type": event_type, "source_tracker_id": self.tracker_id, "target_tracker_id": target_tracker_id, "payload": payload})[0]

    def push_agent_update(self, agent_id, status):
        return self.request("POST", f"/trackers/{self.tracker_id}/agent-update", {"agent_id": agent_id, "status": status})[0]

    def send_remote_message(self, sender_name, sender_agent_id, sender_tracker_id, target_hostname, target_name_or_id, message=None, attachments=None, message_id=None):
        return self.request("POST", "/messages", _remote_message_payload(sender_name, sender_agent_id, sender_tracker_id, target_hostname, target_name_or_id, message, attachments, message_id))

    def fetch_agents(self):
        return self.request("GET", "/agents")

    def fetch_trackers(self):
        return self.request("GET", "/trackers")


def _read_token_config(config):
    if config.get("token"):
        return config.get("token")
    token_file = config.get("token-file") or config.get("tokenFile")
    if token_file:
        try:
            with open(token_file, "r") as f:
                return f.read().strip()
        except Exception as e:
            LOG.warning("failed to read registry token file %s: %s", token_file, e)
    return TOKEN


def load_registry_clients():
    raw = os.environ.get("AGENT_REGISTRIES_JSON", "").strip()
    configs = []
    if raw:
        try:
            decoded = json.loads(raw)
            configs = decoded.get("registries") if isinstance(decoded, dict) else decoded
        except json.JSONDecodeError:
            LOG.warning("invalid AGENT_REGISTRIES_JSON; registry sync disabled")
            configs = []
    elif os.environ.get("AGENT_REGISTRY_URL", "").strip():
        configs = [{"name": "default", "url": os.environ.get("AGENT_REGISTRY_URL"), "token": os.environ.get("AGENT_REGISTRY_TOKEN", "")}]
    clients = []
    for config in configs or []:
        if not isinstance(config, dict) or not config.get("url"):
            continue
        clients.append(RegistryClient(config.get("name") or "default", config.get("url"), _read_token_config(config)))
    return clients


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
            "agent_configs": state.get_local_configs_for_registry(),
        },
    )[0]
    if status in (200, 201):
        LOG.info("registered tracker_id=%s hostname=%s http_port=%s status=%s", TRACKER_ID, HOSTNAME, HTTP_PORT, status)
    else:
        LOG.warning("failed to register tracker_id=%s hostname=%s status=%s", TRACKER_ID, HOSTNAME, status)
    return status


def heartbeat():
    return _request("POST", f"/trackers/{TRACKER_ID}/heartbeat", {
        "agents": state.get_agents_for_registry(),
        "agent_configs": state.get_local_configs_for_registry(),
    })[0]


def push_agent_update(agent_id, status):
    clients = load_registry_clients()
    if clients:
        for client in clients:
            threading.Thread(target=lambda c=client: c.push_agent_update(agent_id, status), daemon=True).start()
    elif REGISTRY_URL:
        threading.Thread(
            target=lambda: _request("POST", f"/trackers/{TRACKER_ID}/agent-update", {"agent_id": agent_id, "status": status}),
            daemon=True,
        ).start()


def _remote_message_payload(sender_name, sender_agent_id, sender_tracker_id, target_hostname, target_name_or_id, message=None, attachments=None, message_id=None):
    payload = {
        "sender_agent_id": sender_agent_id,
        "sender_agent_name": sender_name,
        "sender_tracker_id": sender_tracker_id,
        "message": message,
    }
    if message_id:
        payload["message_id"] = message_id
    if attachments:
        payload["attachments"] = attachments
    try:
        uuid.UUID(target_name_or_id)
        payload["target_agent_id"] = target_name_or_id
    except (ValueError, TypeError):
        payload["target_agent_name"] = target_name_or_id
        payload["target_hostname"] = target_hostname
    return payload


def _client_has_hostname(client, hostname):
    status, body = client.fetch_agents()
    if status != 200:
        return False
    return any(agent.get("hostname") == hostname for agent in (body or {}).get("agents") or [])


def send_remote_message(sender_name, sender_agent_id, sender_tracker_id, target_hostname, target_name_or_id, message=None, attachments=None, message_id=None):
    clients = load_registry_clients()
    if clients:
        if len(clients) == 1:
            return clients[0].send_remote_message(sender_name, sender_agent_id, sender_tracker_id, target_hostname, target_name_or_id, message, attachments, message_id)
        matches = [client for client in clients if _client_has_hostname(client, target_hostname)]
        if len(matches) > 1:
            choices = ", ".join(f"{client.name}:{target_hostname}/{target_name_or_id}" for client in matches)
            return 409, {"message": f"Ambiguous remote target; use one of: {choices}"}
        client = matches[0] if matches else clients[0]
        return client.send_remote_message(sender_name, sender_agent_id, sender_tracker_id, target_hostname, target_name_or_id, message, attachments, message_id)
    return _request("POST", "/messages", _remote_message_payload(sender_name, sender_agent_id, sender_tracker_id, target_hostname, target_name_or_id, message, attachments, message_id))


def send_remote_message_to_registry(registry_name, sender_name, sender_agent_id, sender_tracker_id, target_hostname, target_name_or_id, message=None, attachments=None, message_id=None):
    for client in load_registry_clients():
        if client.name == registry_name:
            return client.request("POST", "/messages", _remote_message_payload(sender_name, sender_agent_id, sender_tracker_id, target_hostname, target_name_or_id, message, attachments, message_id))
    return 404, {"message": f"registry not configured: {registry_name}"}


def fetch_deliveries():
    return _request("GET", f"/trackers/{TRACKER_ID}/deliveries?wait={DELIVERY_WAIT_SECONDS}", timeout=DELIVERY_WAIT_SECONDS + 5)


def fetch_events():
    return _request("GET", f"/trackers/{TRACKER_ID}/events?wait={DELIVERY_WAIT_SECONDS}", timeout=DELIVERY_WAIT_SECONDS + 5)


def fetch_trackers():
    clients = load_registry_clients()
    if clients:
        trackers = []
        last_status, last_body = None, {}
        for client in clients:
            status, body = client.fetch_trackers()
            last_status, last_body = status, body
            if status != 200:
                continue
            for tracker in body.get("trackers") or []:
                trackers.append({**tracker, "registry_name": client.name})
        if trackers:
            return 200, {"trackers": trackers}
        return last_status, last_body
    return _request("GET", "/trackers")


def ack_event(event_id):
    return _request("POST", f"/trackers/{TRACKER_ID}/events/{event_id}/ack", {})[0]


def ack_delivery(message_id):
    status = _request("POST", f"/trackers/{TRACKER_ID}/deliveries/{message_id}/ack", {})[0]
    if status != 200:
        LOG.warning("failed to ack registry delivery message_id=%s tracker_id=%s status=%s", message_id, TRACKER_ID, status)
    return status


def _registry_status_payload(status_code, operation, existing, client=None):
    now = time.time()
    connected = isinstance(status_code, int) and 200 <= status_code < 300
    name = "default" if client is None else client.name
    registry_url = REGISTRY_URL or None if client is None else client.url
    tracker_id = TRACKER_ID if client is None else client.tracker_id
    hostname = HOSTNAME if client is None else client.hostname
    entry = {
        "connected": connected,
        "registry_url": registry_url,
        "tracker_id": tracker_id,
        "hostname": hostname,
        "last_operation": operation,
        "last_attempt": now,
        "status_code": status_code,
    }
    previous = (existing.get("registries") or {}).get(name, existing)
    if connected:
        entry["last_success"] = now
    elif "last_success" in previous:
        entry["last_success"] = previous["last_success"]
        entry["last_error"] = f"{operation}:{status_code if status_code is not None else 'unreachable'}"
    else:
        entry["last_error"] = f"{operation}:{status_code if status_code is not None else 'unreachable'}"
    registries = dict(existing.get("registries") or {})
    registries[name] = entry
    payload = {**entry, "connected": any(r.get("connected") for r in registries.values()), "registries": registries}
    if payload["connected"]:
        successes = [r.get("last_success") for r in registries.values() if r.get("last_success")]
        if successes:
            payload["last_success"] = max(successes)
    return payload


def _record_sync_result(status_code, operation, client=None):
    try:
        os.makedirs(os.path.dirname(STATUS_PATH), exist_ok=True)
        with open(STATUS_PATH, "a+") as f:
            fcntl.flock(f.fileno(), fcntl.LOCK_EX)
            f.seek(0)
            try:
                existing = json.load(f)
            except Exception:
                existing = {}
            payload = _registry_status_payload(status_code, operation, existing, client)
            f.seek(0)
            f.truncate()
            json.dump(payload, f)
            f.flush()
            fcntl.flock(f.fileno(), fcntl.LOCK_UN)
    except Exception as e:
        logging.debug(f"failed to write registry status: {e}")


def _heartbeat_loop(client=None):
    do_register = register if client is None else client.register
    do_heartbeat = heartbeat if client is None else client.heartbeat
    tracker_id = TRACKER_ID if client is None else client.tracker_id
    _record_sync_result(do_register(), "register", client)
    while True:
        status = do_heartbeat()
        if status == 404:
            LOG.warning("registry heartbeat got 404 for tracker_id=%s; re-registering", tracker_id)
            _record_sync_result(do_register(), "register", client)
        else:
            if status != 200:
                LOG.warning("registry heartbeat failed for tracker_id=%s status=%s", tracker_id, status)
            _record_sync_result(status, "heartbeat", client)
        time.sleep(HEARTBEAT_INTERVAL)


def _ack(client, message_id):
    return ack_delivery(message_id) if client is None else client.ack_delivery(message_id)


def _local_tracker_event_payload(event_type, payload):
    sender_name = state.get_agent_name_by_id(payload.get("sender_agent_id")) or payload.get("sender_agent_id") or "unknown"
    target_agent_id = payload.get("reader_agent_id") or payload.get("receiver_agent_id")
    target_agent_name = payload.get("reader_agent_name") or payload.get("receiver_agent_name")
    return sender_name, {
        "target_agent_id": target_agent_id,
        "target_agent_name": target_agent_name,
        "sender": sender_name,
        "message_id": payload.get("message_id"),
    }


def publish_tracker_event(target_tracker_id, event_type, payload):
    LOG.info("publish_tracker_event target_tracker_id=%s event_type=%s payload=%s", target_tracker_id, event_type, payload)
    if target_tracker_id == TRACKER_ID:
        if event_type in {"message_delivered", "message_notified", "message_read"}:
            sender_name, local_payload = _local_tracker_event_payload(event_type, payload)
            LOG.info("publish_tracker_event local fast-path type=%s sender=%s message_id=%s", event_type, sender_name, payload.get("message_id"))
            state.publish_event(event_type, local_payload)
        else:
            state.publish_event(event_type, payload)
        return 200
    clients = load_registry_clients()
    for client in clients:
        status = client.publish_event(target_tracker_id, event_type, payload)
        if status in (200, 202):
            return status
    if REGISTRY_URL:
        return _request("POST", "/tracker-events", {"event_type": event_type, "source_tracker_id": TRACKER_ID, "target_tracker_id": target_tracker_id, "payload": payload})[0]
    return None


def _handle_remote_spin(config_name):
    """Loads local config for config_name and spins a new agent securely locally."""
    home = os.path.expanduser("~")
    config_path = os.path.join(home, ".config", "agent-tracker", "agents", config_name, "config.json")
    if not os.path.isfile(config_path):
        LOG.warning("remote spin request for missing config: %s", config_name)
        return

    try:
        with open(config_path, "r") as f:
            cfg = json.load(f)
        
        directory = cfg.get("directory")
        if not directory:
            directory = home # fallback
        directory = os.path.abspath(os.path.expanduser(directory))

        agent_command = cfg.get("agent-command")
        agent_args = cfg.get("agent-args") or []
        if not agent_command:
            LOG.warning("remote spin request config missing agent-command: %s", config_name)
            return

        # Generate session name from directory leaf
        from ctl_commands.common import spin_session_name
        session = spin_session_name(directory)
        
        command = shlex.join([agent_command] + agent_args)

        from rpc_handler import handle_spin_agent
        env = {
            "PATH": os.environ.get("PATH", ""),
            "TERM": os.environ.get("TERM", "xterm-256color"),
            "HOME": os.environ.get("HOME", os.path.expanduser("~")),
            "USER": os.environ.get("USER", os.environ.get("LOGNAME", "")),
        }
        resolved_name = handle_spin_agent({
            "session": session,
            "command": command,
            "directory": directory,
            "name": session,
            "env": env,
        })
        LOG.info("remote spin request successfully executed for %s: spun as %s", config_name, resolved_name)

    except Exception as e:
        LOG.error("failed to execute remote spin request for %s: %s", config_name, e)


def _event_loop(client=None):
    while True:
        status, body = (fetch_events() if client is None else client.fetch_events())
        if status != 200:
            LOG.debug("tracker event poll status=%s body=%s client=%s", status, body, None if client is None else client.name)
            time.sleep(2)
            continue
        for event in (body or {}).get("events") or []:
            LOG.info("tracker event received client=%s event=%s", None if client is None else client.name, event)
            if event.get("event_type") in {"message_delivered", "message_notified", "message_read"}:
                payload = event.get("payload") or {}
                sender_name, local_payload = _local_tracker_event_payload(event.get("event_type"), payload)
                LOG.info("mapping remote %s sender=%s message_id=%s target=%s", event.get("event_type"), sender_name, payload.get("message_id"), local_payload.get("target_agent_name"))
                state.publish_event(event.get("event_type"), local_payload)
            elif event.get("event_type") == "spin_request":
                payload = event.get("payload") or {}
                config_name = payload.get("config_name")
                if config_name:
                    threading.Thread(target=_handle_remote_spin, args=(config_name,), daemon=True).start()
            ack = ack_event(event.get("event_id")) if client is None else client.ack_event(event.get("event_id"))
            if ack != 200:
                LOG.warning("failed to ack tracker event event_id=%s status=%s", event.get("event_id"), ack)


def _delivery_loop(client=None):
    missing_target_first_seen = {}
    tracker_id = TRACKER_ID if client is None else client.tracker_id
    while True:
        status, body = fetch_deliveries() if client is None else client.fetch_deliveries()
        if status == 404:
            LOG.warning("registry delivery poll got 404 for tracker_id=%s; re-registering", tracker_id)
            register() if client is None else client.register()
            continue
        if status != 200:
            LOG.warning("registry delivery poll failed for tracker_id=%s status=%s body=%s", tracker_id, status, body)
            time.sleep(2)
            continue
        deliveries = (body or {}).get("deliveries") or []
        if not deliveries:
            continue
        LOG.info("received %s queued registry deliveries for tracker_id=%s", len(deliveries), tracker_id)
        from rpc_handler import deliver_local_message, DeliveryTargetNotFound, DeliveryValidationError
        for delivery in deliveries:
            try:
                LOG.info("delivering queued registry message message_id=%s sender_agent_id=%s sender_tracker_id=%s target_agent_id=%s", delivery.get("message_id"), delivery.get("sender_agent_id"), delivery.get("sender_tracker_id"), delivery.get("target_agent_id"))
                deliver_local_message(
                    delivery["target_agent_id"],
                    {
                        "sender": f'{delivery.get("sender_name", "unknown")} (via {delivery.get("sender_tracker", "unknown")})',
                        "timestamp": delivery.get("sent_at"),
                        "message": delivery.get("message"),
                        "attachments": delivery.get("attachments"),
                        "read": False,
                        "message_id": delivery.get("message_id"),
                        "sender_agent_id": delivery.get("sender_agent_id"),
                        "sender_tracker_id": delivery.get("sender_tracker_id"),
                    },
                )
                ack_status = _ack(client, delivery["message_id"])
                if ack_status == 200:
                    missing_target_first_seen.pop(delivery.get("message_id"), None)
                    LOG.info("delivered and acked queued registry message_id=%s target_agent_id=%s", delivery["message_id"], delivery["target_agent_id"])
            except DeliveryValidationError as e:
                logging.warning(f"dropping invalid queued registry message {delivery.get('message_id')}: {e}")
                ack_status = _ack(client, delivery["message_id"])
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
                    ack_status = _ack(client, delivery["message_id"])
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
    clients = load_registry_clients()
    if not clients:
        LOG.info("registry sync disabled: no registry configured")
        return
    if len(clients) == 1 and clients[0].url == REGISTRY_URL:
        LOG.info(
            "starting registry sync tracker_id=%s hostname=%s registry_url=%s heartbeat_interval=%ss delivery_wait=%ss",
            TRACKER_ID,
            HOSTNAME,
            REGISTRY_URL,
            HEARTBEAT_INTERVAL,
            DELIVERY_WAIT_SECONDS,
        )
        threading.Thread(target=_heartbeat_loop, daemon=True).start()
        threading.Thread(target=_event_loop, daemon=True).start()
        _delivery_loop()
        return
    LOG.info("starting registry sync for %s registries tracker_id=%s hostname=%s", len(clients), TRACKER_ID, HOSTNAME)
    for client in clients:
        threading.Thread(target=_heartbeat_loop, args=(client,), daemon=True).start()
        threading.Thread(target=_event_loop, args=(client,), daemon=True).start()
        threading.Thread(target=_delivery_loop, args=(client,), daemon=True).start()
    while True:
        time.sleep(3600)
