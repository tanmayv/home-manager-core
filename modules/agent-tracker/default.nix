{ pkgs, lib, config, ... }:

with lib;

let
  cfg = config.services.agent-tracker;
  agentTrackerFiles = pkgs.stdenv.mkDerivation {
    name = "agent-tracker-files";
    src = ./.;
    installPhase = ''
      mkdir -p $out
      cp -r * $out/
    '';
  };
  palette = import ../palette.nix;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.writeScriptBin "agent-tracker-ctl" ''
        #!${pkgs.python3}/bin/python3
        ${builtins.readFile ./agent-tracker-ctl.py}
      '')
      
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
                tmux split-window -h -d -l 50% -c "#{pane_current_path}" "AGENT_NAME=\"$agent_name\" nvim -c :AgentObserverToggle"
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
    ] ++ (lib.mapAttrsToList (alias: path: 
      pkgs.writeShellApplication {
        name = alias;
        text = ''
          agent-wrapper "${path}" "$@"
        '';
      }
    ) cfg.agents);

    systemd.user.services.agent-tracker = {
      Unit = {
        Description = "Agent Tracker Daemon";
      };
      Service = {
        ExecStart = "${pkgs.python3}/bin/python3 ${agentTrackerFiles}/agent-tracker.py";
        Restart = "always";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    programs.tmux.statusBar.extraLines = mkIf cfg.enableTmuxIntegration [
      {
        name = "agents";
        command = "#[fg=${palette.color4},bold] Active Agents: #[fg=${palette.color8},nobold]#(agent-tracker-ctl status-bar)";
        condition = "[ $(agent-tracker-ctl list | python3 -c 'import sys, json; print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0) -gt 0 ]";
      }
    ];

    # Contribute tmux configuration if enabled
    programs.tmux.extraConfig = mkIf cfg.enableTmuxIntegration ''
      # Agent navigation contributed by agent-tracker extension
      bind-key N run-shell "agent-tracker-ctl focus --next"
      bind-key P run-shell "agent-tracker-ctl focus --prev"
    '';
  };
}
