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
        
        # Parse --obs flag
        obs_enabled=false
        new_args=()
        for arg in "$@"; do
          if [[ "$arg" == "--obs" ]]; then
            obs_enabled=true
          else
            new_args+=("$arg")
          fi
        done
        set -- "''${new_args[@]}"

        # Detect Agent Swarm session directory in the arguments
        session_dir=""
        for arg in "$@"; do
          if [[ "$arg" =~ (google3/experimental/users/[^/]+/agent_swarm_sessions/[^/\`\ ]+) ]]; then
             session_path="''${BASH_REMATCH[1]}"
             if [[ "$session_path" == google3/* ]]; then
                if [[ "$PWD" == /google/src/cloud/$USER/* ]]; then
                   ws_part="''${PWD#/google/src/cloud/"$USER"/}"
                   ws_name="''${ws_part%%/*}"
                   session_dir="/google/src/cloud/$USER/$ws_name/$session_path"
                fi
             fi
             break
          fi
        done

        # Create the session directory proactively to allow Neovim to watch it on startup
        if [[ -n "$session_dir" ]]; then
          mkdir -p "$session_dir"
        fi

        if [[ -n "''${TMUX:-}" ]]; then
          pane_id="$TMUX_PANE"
          session_name=$(tmux display-message -p '#S')
          
          # Register with agent-tracker and get name! (Foreground)
          tmux_socket="''${TMUX%%,*}"
          wrapper_pid="$$"
          suggested_name="''${SUGGESTED_AGENT_NAME:-}"
          agent_type=$(basename "$cmd")
          agent_name=$(python3 -c "import socket, json, os, sys; s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect(os.path.expanduser('~/.cache/agent-tracker.sock')); s.sendall(json.dumps({'jsonrpc': '2.0', 'method': 'register', 'params': {'session': sys.argv[1], 'tmux_pane': sys.argv[2], 'wrapper_pid': int(sys.argv[3]), 'tmux_socket': sys.argv[4], 'name': sys.argv[5], 'agent_type': sys.argv[6], 'agent_cmd': sys.argv[7]}, 'id': 1}).encode()); s.shutdown(socket.SHUT_WR); resp = s.recv(1024); data = json.loads(resp.decode()); print(data.get(\"result\", \"\"))" "$session_name" "$pane_id" "$wrapper_pid" "$tmux_socket" "$suggested_name" "$agent_type" "$(basename "$cmd")" 2>>/tmp/wrapper.log)
          
          cleanup() {
            tmux set-option -p -u -t "''${pane_id}" @agent_name
            tmux set-option -p -u -t "''${pane_id}" @agent_type
            tmux select-pane -t "''${pane_id}" -T ""
            tmux-status-refresh
          }
          trap cleanup EXIT

          if [[ -n "$agent_name" ]]; then
            # Set identity
            tmux set-option -p -t "''${pane_id}" @agent_name "$agent_name"
            tmux set-option -p -t "''${pane_id}" @agent_type "$agent_type"
            tmux set-option -p -t "''${pane_id}" @agent_cmd "$(basename "$cmd")"
            tmux select-pane -t "''${pane_id}" -T "$agent_name"
            export AGENT_NAME="$agent_name"
            tmux-status-refresh

            # Open observer if requested and nvim is available
            if [[ "$obs_enabled" == "true" ]] && command -v nvim &> /dev/null; then
              # Split 1: Codebase observer (watches CWD/current workspace) on the right (50% width)
              right_pane_id=$(tmux split-window -h -l 70% -d -c "#{pane_current_path}" -P -F "#{pane_id}" "AGENT_NAME=\"$agent_name\" nvim -c :AgentObserverToggle")

              # Split 2: Swarm session directory observer (watches session folder) split vertically below Split 1
              if [[ -n "$session_dir" ]]; then
                tmux split-window -v -d -t "$right_pane_id" -c "#{pane_current_path}" "AGENT_NAME=\"$agent_name\" AGENT_OBSERVER_BASE_DIR=\"$session_dir\" nvim -c :AgentObserverToggle"
              fi
            fi
          fi
          
          # Run the tool in FOREGROUND to keep TUI interactive
          "$cmd" "$@"
        else
          # Fallback for non-tmux environments
          "$cmd" "$@"
        fi
      '';
    })
  ];
}
