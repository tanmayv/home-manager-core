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

          async def check_alive():
              while True:
                  await asyncio.sleep(5)
                  to_remove = []
                  for name, info in state.items():
                      pid = info.get("pid")
                      if pid:
                          try:
                              os.kill(pid, 0)
                          except ProcessLookupError:
                              to_remove.append(name)
                          except PermissionError:
                              pass
                          except Exception:
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
