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
          pane_id="$TMUX_PANE"
          session_name=$(tmux display-message -p '#S')
          
          # Register with agent-tracker and get name! (Foreground)
          tmux_socket="''${TMUX%%,*}"
          wrapper_pid="$$"
          suggested_name="''${SUGGESTED_AGENT_NAME:-}"
          agent_name=$(python3 -c "import socket, json, os, sys; s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect(os.path.expanduser('~/.cache/agent-tracker.sock')); s.sendall(json.dumps({'jsonrpc': '2.0', 'method': 'register', 'params': {'session': sys.argv[1], 'tmux_pane': sys.argv[2], 'wrapper_pid': int(sys.argv[3]), 'tmux_socket': sys.argv[4], 'suggested_name': sys.argv[5]}, 'id': 1}).encode()); resp = s.recv(1024); data = json.loads(resp.decode()); print(data.get(\"result\", \"\"))" "$session_name" "$pane_id" "$wrapper_pid" "$tmux_socket" "$suggested_name" 2>>/tmp/wrapper.log)
          
          if [[ -n "$agent_name" ]]; then
            # Set identity
            tmux set-option -p -t "''${pane_id}" @agent_name "$agent_name"
            tmux select-pane -t "''${pane_id}" -T "$agent_name"
            tmux-status-refresh
          fi
          
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
