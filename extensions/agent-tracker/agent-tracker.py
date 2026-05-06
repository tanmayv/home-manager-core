import logging
import os
import socket
import sys
import threading
import time

import state
import monitor
import rpc_handler

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s', stream=sys.stderr)

SOCKET_PATH = os.environ.get("AGENT_TRACKER_SOCKET", os.path.expanduser("~/.cache/agent-tracker.sock"))

def main():
    os.makedirs(os.path.dirname(SOCKET_PATH), exist_ok=True)
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(SOCKET_PATH)
        logging.error(f"Another instance of agent-tracker is already listening on {SOCKET_PATH}")
        sys.exit(1)
    except ConnectionRefusedError:
        logging.info(f"Stale socket found at {SOCKET_PATH}, removing it.")
        os.remove(SOCKET_PATH)
    except FileNotFoundError:
        pass

    state.init_state()
    
    # Start background monitor thread
    threading.Thread(target=monitor.background_monitor, daemon=True).start()

    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCKET_PATH)
    server.listen(10)
    
    logging.info(f"Agent Tracker listening on {SOCKET_PATH}")

    while True:
        try:
            conn, _ = server.accept()
            # Each connection gets its own thread for parallelism
            threading.Thread(target=rpc_handler.handle_client, args=(conn,), daemon=True).start()
        except socket.error as e:
            logging.error(f"Server accept error: {e}")
            time.sleep(1)

if __name__ == "__main__":
    main()
