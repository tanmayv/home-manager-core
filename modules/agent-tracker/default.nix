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
                    running_tool = info.get("running_tool", False)
                    
                    color = "#414868" # Default inactive (gray)
                    if running_tool:
                        color = "#db4b4b" # Red for running tool
                    elif pane == current_pane:
                        color = "#e0af68" # Yellow for active pane

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
          import asyncio
          import json
          import os
          import sys

          SOCKET_PATH = os.path.expanduser("~/.cache/agent-tracker.sock")
          state = {}

          async def handle_client(reader, writer):
              try:
                  data = await reader.read(1024)
                  if not data:
                      return
                  message = data.decode()
                  try:
                      req = json.loads(message)
                  except json.JSONDecodeError:
                      writer.write(json.dumps({"jsonrpc": "2.0", "error": {"code": -32700, "message": "Parse error"}, "id": None}).encode())
                      await writer.drain()
                      writer.close()
                      return

                  method = req.get("method")
                  params = req.get("params", {})
                  req_id = req.get("id")

                  result = None
                  error = None

                  if method == "register":
                      agent_name = params.get("agent_name")
                      session = params.get("session")
                      tmux_pane = params.get("tmux_pane")
                      pid = params.get("pid")
                      tmux_socket = params.get("tmux_socket")
                      if agent_name and session and tmux_pane and pid and tmux_socket:
                          state[agent_name] = {"session": session, "tmux_pane": tmux_pane, "pid": pid, "tmux_socket": tmux_socket}
                          result = True
                      else:
                          error = {"code": -32602, "message": "Invalid params"}
                  elif method == "list":
                      result = state
                  elif method == "update_agent":
                      agent_name = params.get("agent_name")
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
                          if agent_name in state:
                              info = state[agent_name]
                              import subprocess
                              try:
                                  full_msg = f"From {sender_name}: {msg}"
                                  subprocess.run(["tmux", "-S", info["tmux_socket"], "send-keys", "-t", info["tmux_pane"], full_msg, "Enter"], check=True)
                                  result = True
                              except Exception as e:
                                  print(f"Failed to send keys: {e}")
                                  error = {"code": -32000, "message": f"Failed to send keys: {e}"}
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

                  writer.write(json.dumps(resp).encode())
                  await writer.drain()
              except Exception as e:
                  print(f"Error handling client: {e}")
              finally:
                  writer.close()

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

          async def check_alive():
              while True:
                  await asyncio.sleep(5)
                  to_remove = []
                  for name, info in state.items():
                      pid = info.get("pid")
                      if pid and not is_process_alive(pid):
                          to_remove.append(name)
                  for name in to_remove:
                      print(f"Removing dead agent: {name}")
                      del state[name]

          async def main():
              os.makedirs(os.path.dirname(SOCKET_PATH), exist_ok=True)
              if os.path.exists(SOCKET_PATH):
                  os.remove(SOCKET_PATH)

              server = await asyncio.start_unix_server(handle_client, path=SOCKET_PATH)

              print(f"Agent Tracker listening on {SOCKET_PATH}")
              
              # Start periodic check
              asyncio.create_task(check_alive())
              
              async with server:
                  await server.serve_forever()

          if __name__ == "__main__":
              asyncio.run(main())
        ''}/bin/agent-tracker";
        Restart = "always";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
