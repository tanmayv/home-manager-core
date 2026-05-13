{ pkgs, config, ... }:

let
  trackerSocketPath = "${(config.xdg.cacheHome or "${config.home.homeDirectory}/.cache")}/agent-tracker/agent-tracker.sock";
in
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



        if [[ -n "''${TMUX:-}" ]]; then
          pane_id="$TMUX_PANE"
          session_name=$(tmux display-message -p '#S')

          export AGENT_TRACKER_SOCKET="''${AGENT_TRACKER_SOCKET:-${trackerSocketPath}}"
          agent-tracker-ctl ensure-running >/dev/null 2>&1 || true
          
          # Register with agent-tracker and get name! (Foreground)
          tmux_socket="''${TMUX%%,*}"
          wrapper_pid="$$"
          suggested_name="''${SUGGESTED_AGENT_NAME:-}"
          agent_type=$(basename "$cmd")
          agent_name=$(python3 -c "import socket, json, os, sys; s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect(os.environ.get('AGENT_TRACKER_SOCKET', os.path.join(os.path.expanduser('~/.cache'), 'agent-tracker', 'agent-tracker.sock'))); s.sendall(json.dumps({'jsonrpc': '2.0', 'method': 'register', 'params': {'session': sys.argv[1], 'tmux_pane': sys.argv[2], 'wrapper_pid': int(sys.argv[3]), 'tmux_socket': sys.argv[4], 'name': sys.argv[5], 'agent_type': sys.argv[6], 'agent_cmd': sys.argv[7]}, 'id': 1}).encode()); s.shutdown(socket.SHUT_WR); resp = s.recv(1024); data = json.loads(resp.decode()); print(data.get(\"result\", \"\"))" "$session_name" "$pane_id" "$wrapper_pid" "$tmux_socket" "$suggested_name" "$agent_type" "$(basename "$cmd")" 2>>/tmp/wrapper.log)
          
          cleanup() {
            tty=$(tmux display-message -p -t "''${pane_id}" '#{pane_tty}' 2>/dev/null || true)
            shell_pid=$(tmux display-message -p -t "''${pane_id}" '#{pane_pid}' 2>/dev/null || true)

            if [[ -n "$tty" && -n "$shell_pid" ]]; then
              pts_name="''${tty#/dev/}"
              if ps -t "$pts_name" -o pid=,comm=,args= 2>/dev/null | \
                awk -v shell_pid="$shell_pid" '
                  $1 != shell_pid && $2 !~ /^(ps|grep|pgrep|ls|cat|sleep|which|sh|bash|zsh|fish|tmux|home-manager|nix|env)$/ {
                    print; found=1; exit
                  }
                  END { exit(found ? 0 : 1) }
                '; then
                tmux-status-refresh
                return
              fi
            fi

            tmux set-option -p -u -t "''${pane_id}" @agent_name
            tmux set-option -p -u -t "''${pane_id}" @agent_type
            tmux set-option -p -u -t "''${pane_id}" @agent_cmd
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
              # Split 1: Primary observer (watches CWD) on the right
              right_pane_id=$(tmux split-window -h -l 70% -d -c "#{pane_current_path}" -P -F "#{pane_id}" "AGENT_NAME=\"$agent_name\" nvim -c :AgentObserverToggle")

              # Split remaining observers if specified in AGENT_OBSERVERS (newline-separated commands)
              if [[ -n "''${AGENT_OBSERVERS:-}" ]]; then
                while IFS= read -r obs_cmd; do
                  if [[ -n "$obs_cmd" ]]; then
                    tmux split-window -v -d -t "$right_pane_id" -c "#{pane_current_path}" "$obs_cmd"
                  fi
                done <<< "''${AGENT_OBSERVERS}"
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
