{ pkgs, config }:

let
  trackerSocketPath = "${(config.xdg.cacheHome or "${config.home.homeDirectory}/.cache")}/agent-tracker/agent-tracker.sock";
in
pkgs.writeShellApplication {
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

    # Parse wrapper flags
    obs_enabled=false
    no_notify_with_send_keys=false
    no_registry=false
    new_args=()
    for arg in "$@"; do
      if [[ "$arg" == "--obs" ]]; then
        obs_enabled=true
      elif [[ "$arg" == "--no-notify-with-send-keys" ]]; then
        no_notify_with_send_keys=true
      elif [[ "$arg" == "--no-registry" ]]; then
        no_registry=true
      else
        new_args+=("$arg")
      fi
    done
    set -- "''${new_args[@]}"

    if [[ -n "''${TMUX:-}" ]]; then
      pane_id="$TMUX_PANE"
      session_name=$(tmux display-message -p -t "$pane_id" '#S')

      export AGENT_TRACKER_SOCKET="''${AGENT_TRACKER_SOCKET:-${trackerSocketPath}}"
      agent-tracker-ctl ensure-running >/dev/null 2>&1 || true

      # Register with agent-tracker and get name! (Foreground)
      tmux_socket="''${TMUX%%,*}"
      wrapper_pid="$$"
      last_sent_session="$session_name"
      last_sent_pane="$pane_id"
      last_sent_socket="$tmux_socket"
      suggested_name="''${SUGGESTED_AGENT_NAME:-}"
      agent_type=$(basename "$cmd")
      agent_id="''${AGENT_ID:-$(python3 -c 'import uuid; print(uuid.uuid4())')}"
      export AGENT_ID="$agent_id"
      agent_name=$(python3 -c "import socket, json, os, sys; s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect(os.environ.get('AGENT_TRACKER_SOCKET', os.path.join(os.path.expanduser('~/.cache'), 'agent-tracker', 'agent-tracker.sock'))); s.sendall(json.dumps({'jsonrpc': '2.0', 'method': 'register', 'params': {'session': sys.argv[1], 'tmux_pane': sys.argv[2], 'wrapper_pid': int(sys.argv[3]), 'tmux_socket': sys.argv[4], 'name': sys.argv[5], 'agent_type': sys.argv[6], 'agent_cmd': sys.argv[7], 'agent_id': sys.argv[8], 'no_notify_with_send_keys': sys.argv[9].lower() == 'true', 'no_registry': sys.argv[10].lower() == 'true'}, 'id': 1}).encode()); s.shutdown(socket.SHUT_WR); resp = s.recv(1024); data = json.loads(resp.decode()); print(data.get(\"result\", \"\"))" "$session_name" "$pane_id" "$wrapper_pid" "$tmux_socket" "$suggested_name" "$agent_type" "$(basename "$cmd")" "$agent_id" "$no_notify_with_send_keys" "$no_registry" 2>>/tmp/wrapper.log)

      resolve_tmux_location() {
        local current_session current_pane current_socket
        current_session=$(tmux display-message -p -t "$pane_id" '#S' 2>/dev/null || true)
        current_pane=$(tmux display-message -p -t "$pane_id" '#{pane_id}' 2>/dev/null || true)
        current_socket=$(tmux display-message -p -t "$pane_id" '#{socket_path}' 2>/dev/null || true)

        if [[ -z "$current_socket" ]]; then
          current_socket="$tmux_socket"
        fi

        printf '%s\t%s\t%s\n' "$current_session" "$current_pane" "$current_socket"
      }

      send_heartbeat() {
        local location current_session current_pane current_socket session_arg pane_arg socket_arg
        location=$(resolve_tmux_location)
        IFS=$'\t' read -r current_session current_pane current_socket <<< "$location"

        session_arg="__UNCHANGED__"
        pane_arg="__UNCHANGED__"
        socket_arg="__UNCHANGED__"

        if [[ -n "$current_session" && "$current_session" != "$last_sent_session" ]]; then
          session_arg="$current_session"
        fi
        if [[ -n "$current_pane" && "$current_pane" != "$last_sent_pane" ]]; then
          pane_arg="$current_pane"
        fi
        if [[ -n "$current_socket" && "$current_socket" != "$last_sent_socket" ]]; then
          socket_arg="$current_socket"
        fi

        if python3 -c "import json, os, socket, sys; params = {'agent_id': sys.argv[1], 'wrapper_pid': int(sys.argv[5])}; sentinel = '__UNCHANGED__'; session = sys.argv[2]; pane = sys.argv[3]; tmux_socket = sys.argv[4]; session != sentinel and params.__setitem__('session', session); pane != sentinel and params.__setitem__('tmux_pane', pane); tmux_socket != sentinel and params.__setitem__('tmux_socket', tmux_socket); s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.settimeout(2.0); s.connect(os.environ['AGENT_TRACKER_SOCKET']); s.sendall(json.dumps({'jsonrpc': '2.0', 'method': 'heartbeat', 'params': params, 'id': 1}).encode()); s.shutdown(socket.SHUT_WR); data = json.loads(s.recv(1024).decode()); sys.exit(0 if 'result' in data else 1)" "$agent_id" "$session_arg" "$pane_arg" "$socket_arg" "$wrapper_pid" >/dev/null 2>>/tmp/wrapper.log; then
          if [[ -n "$current_session" ]]; then
            last_sent_session="$current_session"
          fi
          if [[ -n "$current_pane" ]]; then
            last_sent_pane="$current_pane"
          fi
          if [[ -n "$current_socket" ]]; then
            last_sent_socket="$current_socket"
          fi
          return 0
        fi
        return 1
      }

      reregister_agent() {
        local location current_session current_pane current_socket current_name
        location=$(resolve_tmux_location)
        IFS=$'\t' read -r current_session current_pane current_socket <<< "$location"
        current_session="''${current_session:-$last_sent_session}"
        current_pane="''${current_pane:-$last_sent_pane}"
        current_socket="''${current_socket:-$last_sent_socket}"
        current_name=$(tmux display-message -p -t "$current_pane" '#{@agent_name}' 2>/dev/null || true)
        if python3 -c "import socket, json, os, sys; s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.settimeout(2.0); s.connect(os.environ['AGENT_TRACKER_SOCKET']); s.sendall(json.dumps({'jsonrpc': '2.0', 'method': 'register', 'params': {'session': sys.argv[1], 'tmux_pane': sys.argv[2], 'wrapper_pid': int(sys.argv[3]), 'tmux_socket': sys.argv[4], 'name': sys.argv[5], 'agent_type': sys.argv[6], 'agent_cmd': sys.argv[7], 'agent_id': sys.argv[8], 'no_notify_with_send_keys': sys.argv[9].lower() == 'true', 'no_registry': sys.argv[10].lower() == 'true'}, 'id': 1}).encode()); s.shutdown(socket.SHUT_WR); data = json.loads(s.recv(1024).decode()); print(data.get(\"result\", \"\"))" "$current_session" "$current_pane" "$wrapper_pid" "$current_socket" "$current_name" "$agent_type" "$(basename "$cmd")" "$agent_id" "$no_notify_with_send_keys" "$no_registry" >/dev/null 2>>/tmp/wrapper.log; then
          last_sent_session="$current_session"
          last_sent_pane="$current_pane"
          last_sent_socket="$current_socket"
          return 0
        fi
        return 1
      }

      start_heartbeat() {
        (
          while true; do
            if ! send_heartbeat; then
              agent-tracker-ctl ensure-running >/dev/null 2>&1 || true
              reregister_agent
            fi
            sleep 5
          done
        ) &
        heartbeat_pid=$!
      }

      heartbeat_pid=""

      cleanup() {
        if [[ -n "$heartbeat_pid" ]]; then
          kill "$heartbeat_pid" >/dev/null 2>&1 || true
        fi
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

        agent-tracker-ctl unregister --pane "$pane_id" >/dev/null 2>&1 || true
        tmux set-option -p -u -t "''${pane_id}" @agent_name
        tmux set-option -p -u -t "''${pane_id}" @agent_id
        tmux set-option -p -u -t "''${pane_id}" @agent_uuid
        tmux set-option -p -u -t "''${pane_id}" @agent_type
        tmux set-option -p -u -t "''${pane_id}" @agent_cmd
        tmux set-option -p -u -t "''${pane_id}" @agent_no_notify_with_send_keys
        tmux set-option -p -u -t "''${pane_id}" @agent_no_registry
        tmux select-pane -t "''${pane_id}" -T ""
        tmux-status-refresh
      }
      trap cleanup EXIT

      if [[ -n "$agent_name" ]]; then
        # Set identity
        tmux set-option -p -t "''${pane_id}" @agent_name "$agent_name"
        tmux set-option -p -t "''${pane_id}" @agent_id "$agent_id"
        tmux set-option -p -t "''${pane_id}" @agent_uuid "$agent_id"
        tmux set-option -p -t "''${pane_id}" @agent_type "$agent_type"
        tmux set-option -p -t "''${pane_id}" @agent_cmd "$(basename "$cmd")"
        tmux set-option -p -t "''${pane_id}" @agent_no_notify_with_send_keys "$( [[ "$no_notify_with_send_keys" == "true" ]] && echo on || echo off )"
        tmux set-option -p -t "''${pane_id}" @agent_no_registry "$( [[ "$no_registry" == "true" ]] && echo on || echo off )"
        tmux select-pane -t "''${pane_id}" -T "$agent_name"
        export AGENT_NAME="$agent_name"
        start_heartbeat
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
}
