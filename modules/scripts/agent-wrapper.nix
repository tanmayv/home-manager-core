{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "agent-wrapper";
      runtimeInputs = with pkgs; [
        tmux
        coreutils
        gnugrep
        python3
        procps
      ];

      text = ''
        cmd="$1"
        shift
        
        if [[ -n "''${TMUX:-}" ]]; then
          pane_id=$(tmux display-message -p '#{pane_id}')
          session_name=$(tmux display-message -p '#S')
          
          # 1. Figure out name (Foreground)
          # Call agent-tracker to get active names and compute next one
          agent_name=$(python3 - <<EOF
import socket, json, os
try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(os.path.expanduser('~/.cache/agent-tracker.sock'))
    s.sendall(json.dumps({'jsonrpc': '2.0', 'method': 'list', 'id': 1}).encode())
    resp = s.recv(4096)
    data = json.loads(resp.decode())
    agents = data.get('result', {})
except Exception:
    agents = {}

session_name = "$session_name"
num = 1
while f"{session_name}-agent-{num}" in agents:
    num += 1
print(f"{session_name}-agent-{num}")
EOF
)
          
          # 2. Set identity (Foreground)
          tmux set-option -p -t "''${pane_id}" @agent_name "$agent_name"
          tmux select-pane -t "''${pane_id}" -T "$agent_name"
          tmux-status-refresh

          # 3. Background watcher for PID and registration
          (
            # Wait for command to start
            sleep 1
            
            # Find newest child of parent shell ($$)
            pid=$(pgrep -P $$ | sort -n | tail -n 1)
            
            # Register with agent-tracker
            tmux_socket="''${TMUX%%,*}"
            python3 -c "import socket, json, os, sys; s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect(os.path.expanduser('~/.cache/agent-tracker.sock')); s.sendall(json.dumps({'jsonrpc': '2.0', 'method': 'register', 'params': {'agent_name': sys.argv[1], 'session': sys.argv[2], 'tmux_pane': sys.argv[3], 'pid': int(sys.argv[4]), 'tmux_socket': sys.argv[5]}, 'id': 1}).encode())" "$agent_name" "$session_name" "$pane_id" "$pid" "$tmux_socket" 2>/dev/null || true
          ) &
          
          # Run the tool in FOREGROUND to keep TUI interactive
          "$cmd" "$@"

          # Cleanup
          tmux set-option -p -u @agent_name
          tmux select-pane -T ""
          tmux-status-refresh
        else
          # Fallback for non-tmux environments
          "$cmd" "$@"
        fi
      '';
    })
  ];
}
