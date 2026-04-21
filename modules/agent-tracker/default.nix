{ pkgs, lib, config, ... }:

with lib;

let
  cfg = config.services.agent-tracker;
in
{
  options.services.agent-tracker = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable agent-tracker daemon";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.writeScriptBin "agent-tracker-ctl" ''
        #!${pkgs.python3}/bin/python3
        import argparse
        import json
        import os
        import socket
        import subprocess
        import sys

        SOCKET_PATH = os.path.expanduser("~/.cache/agent-tracker.sock")

        def call_rpc(method, params={}):
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.connect(SOCKET_PATH)
                s.sendall(json.dumps({"jsonrpc": "2.0", "method": method, "params": params, "id": 1}).encode())
                resp = s.recv(4096)
                data = json.loads(resp.decode())
                if "error" in data:
                    print(f"Error: {data['error']['message']}", file=sys.stderr)
                    sys.exit(1)
                return data.get("result")
            except Exception as e:
                print(f"Failed to connect to tracker: {e}", file=sys.stderr)
                sys.exit(1)

        def main():
            parser = argparse.ArgumentParser(description="Agent Tracker Control")
            subparsers = parser.add_subparsers(dest="command", help="Subcommands")

            subparsers.add_parser("list", help="List agents in JSON format")
            subparsers.add_parser("status-bar", help="List agents for status bar")

            send_parser = subparsers.add_parser("send-message", help="Send message to agent")
            send_parser.add_argument("agent_name", help="Target agent name")
            send_parser.add_argument("message", help="Message text")

            focus_parser = subparsers.add_parser("focus", help="Focus agent pane")
            focus_parser.add_argument("agent_name", help="Agent name to focus")

            args = parser.parse_args()

            if args.command == "list":
                agents = call_rpc("list")
                print(json.dumps(agents))

            elif args.command == "status-bar":
                agents = call_rpc("list")
                if not agents:
                    sys.exit(0)

                try:
                    current_pane = subprocess.check_output(["tmux", "display-message", "-p", "#{pane_id}"]).decode("utf-8").strip()
                except:
                    current_pane = ""

                formatted = []
                for name, info in agents.items():
                    pane = info.get("tmux_pane")
                    waiting_approval = info.get("waiting_approval", False)
                    status = info.get("status", "")
                    
                    color = "#414868" # Fallback (Gray)
                    if waiting_approval:
                        color = "#db4b4b" # Red for Waiting for Approval
                    elif pane == current_pane:
                        color = "#e0af68" # Yellow for Active Pane
                    elif status == "working":
                        color = "#7dcfff" # Cyan for Working
                    elif status == "idle":
                        color = "#9ece6a" # Green for Idle

                    range_arg = f"agent:{pane}"
                    formatted.append(f"#[range=user|{range_arg}]#[fg={color},bold]{name}#[fg=#414868,nobold]#[norange]")

                print(" · ".join(formatted))

            elif args.command == "send-message":
                call_rpc("send_message", {"sender_name": "cli-user", "agent_name": args.agent_name, "message": args.message})
                print("Message sent.")

            elif args.command == "focus":
                agents = call_rpc("list")
                if args.agent_name in agents:
                    info = agents[args.agent_name]
                    session = info.get("session")
                    pane = info.get("tmux_pane")
                    socket_path = info.get("tmux_socket")

                    tmux_cmd = ["tmux"]
                    if socket_path:
                        tmux_cmd.extend(["-S", socket_path])

                    subprocess.run(tmux_cmd + ["switch-client", "-t", session])
                    subprocess.run(tmux_cmd + ["select-pane", "-t", pane])
                else:
                    print(f"Agent {args.agent_name} not found.", file=sys.stderr)
                    sys.exit(1)
            else:
                parser.print_help()

        if __name__ == "__main__":
            main()
      '')
    ];

    systemd.user.services.agent-tracker = {
      Unit = {
        Description = "Agent Tracker Daemon";
      };
      Service = {
        ExecStart = "${pkgs.writeScriptBin "agent-tracker" ''
          #!${pkgs.python3}/bin/python3
          import json
          import logging
          import os
          import socket
          import sys

          logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s', stream=sys.stderr)
          POLL_INTERVAL = int(os.environ.get("POLL_INTERVAL", 5))
          import threading
          import queue
          import subprocess
          import time

          SOCKET_PATH = os.path.expanduser("~/.cache/agent-tracker.sock")
          state = {}
          state_lock = threading.Lock()
          # Queue for slow tasks (like tmux interactions) to avoid blocking listener threads
          task_queue = queue.Queue()

          def tmux_worker():
              """Worker thread for executing tmux commands sequentially."""
              while True:
                  task = task_queue.get()
                  if task is None: break
                  try:
                      cmd = task['cmd']
                      # Use a reasonable timeout for tmux commands
                      subprocess.run(cmd, check=True, capture_output=True, timeout=5)
                  except Exception as e:
                      logging.error(f"Tmux worker error: {e}")
                  finally:
                      task_queue.task_done()

          # Start tmux worker
          threading.Thread(target=tmux_worker, daemon=True).start()

          def is_process_alive(pid):
              try:
                  state_char = None
                  ppid = None
                  with open(f"/proc/{pid}/status", "r") as f:
                      for line in f:
                          if line.startswith("State:"):
                              state_char = line.split()[1]
                          elif line.startswith("PPid:"):
                              ppid = int(line.split()[1])
                  
                  if state_char is None or ppid is None:
                      return False
                      
                  # Consider dead if zombie or orphaned (PPid == 1)
                  if state_char == "Z" or ppid == 1:
                      return False
                  return True
              except FileNotFoundError:
                  return False
              except Exception:
                  return False

          def background_monitor():
              """Periodically checks process health and scrapes panes for status."""
              while True:
                  time.sleep(POLL_INTERVAL)
                  to_remove = []
                  
                  with state_lock:
                      agents_snapshot = {name: info.copy() for name, info in state.items()}
                      
                  for name, info in agents_snapshot.items():
                      wrapper_pid = info.get("wrapper_pid")
                      if wrapper_pid and not is_process_alive(wrapper_pid):
                          to_remove.append(name)
                          continue

                      # Update child PID if not already known
                      if not info.get("pid") and wrapper_pid:
                          try:
                              out = subprocess.check_output(["pgrep", "-P", str(wrapper_pid)], timeout=1).decode("utf-8").strip()
                              if out:
                                  actual_pid = int(out.split()[0])
                                  with state_lock:
                                      if name in state:
                                          state[name]["pid"] = actual_pid
                          except:
                              pass

                  if to_remove:
                      with state_lock:
                          for name in to_remove:
                              logging.info(f"Removing dead agent: {name}")
                              if name in state:
                                  del state[name]

          def handle_client(conn):
              try:
                  conn.settimeout(2.0) # Safety timeout for reads
                  data = conn.recv(4096)
                  if not data:
                      return
                  
                  try:
                      req = json.loads(data.decode())
                  except json.JSONDecodeError:
                      return

                  method = req.get("method")
                  params = req.get("params", {})
                  req_id = req.get("id")

                  result = None
                  error = None

                  if method == "register":
                      session = params.get("session")
                      tmux_pane = params.get("tmux_pane")
                      wrapper_pid = params.get("wrapper_pid")
                      tmux_socket = params.get("tmux_socket")
                      if session and tmux_pane and wrapper_pid and tmux_socket:
                          with state_lock:
                              num = 1
                              while f"{session}-agent-{num}" in state:
                                  num += 1
                              agent_name = f"{session}-agent-{num}"
                              
                              state[agent_name] = {
                                  "session": session, 
                                  "tmux_pane": tmux_pane, 
                                  "wrapper_pid": wrapper_pid, 
                                  "tmux_socket": tmux_socket, 
                                  "pid": None,
                                  "status": "idle",
                                  "waiting_approval": False
                              }
                              result = agent_name
                      else:
                          error = {"code": -32602, "message": "Invalid params"}
                  elif method == "list":
                      with state_lock:
                          result = {k: v.copy() for k, v in state.items()}
                  elif method == "update_agent":
                      agent_name = params.get("agent_name")
                      with state_lock:
                          if agent_name in state:
                              for k, v in params.items():
                                  if k != "agent_name":
                                      state[agent_name][k] = v
                              result = True
                          else:
                              error = {"code": -32602, "message": "Agent not found"}
                  elif method == "send_message":
                      sender_name = params.get("sender_name")
                      agent_name = params.get("agent_name")
                      msg = params.get("message")
                      
                      if sender_name and agent_name and msg:
                          with state_lock:
                              if agent_name in state:
                                  info = state[agent_name]
                                  full_msg = f"From {sender_name}: {msg}"
                                  # Queue the slow tmux interaction to keep this thread responsive
                                  task_queue.put({'cmd': ["tmux", "-S", info["tmux_socket"], "send-keys", "-t", info["tmux_pane"], full_msg, "Enter"]})
                                  result = True
                              else:
                                  error = {"code": -32602, "message": "Target agent not found"}
                      else:
                          error = {"code": -32602, "message": "Invalid params"}
                  else:
                      error = {"code": -32601, "message": "Method not found"}

                  resp = {"jsonrpc": "2.0", "id": req_id}
                  if error:
                      resp["error"] = error
                  else:
                      resp["result"] = result

                  conn.sendall(json.dumps(resp).encode())
              except Exception as e:
                  logging.error(f"Error handling client: {e}")
              finally:
                  conn.close()

          def main():
              os.makedirs(os.path.dirname(SOCKET_PATH), exist_ok=True)
              if os.path.exists(SOCKET_PATH):
                  os.remove(SOCKET_PATH)

              # Start background monitor thread
              threading.Thread(target=background_monitor, daemon=True).start()

              server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
              server.bind(SOCKET_PATH)
              server.listen(10)
              
              logging.info(f"Agent Tracker listening on {SOCKET_PATH}")

              while True:
                  try:
                      conn, _ = server.accept()
                      # Each connection gets its own thread for parallelism
                      threading.Thread(target=handle_client, args=(conn,), daemon=True).start()
                  except Exception as e:
                      logging.error(f"Server accept error: {e}")
                      time.sleep(1)

          if __name__ == "__main__":
              main()
        ''}/bin/agent-tracker";
        Restart = "always";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
