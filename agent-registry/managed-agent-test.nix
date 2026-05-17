{ pkgs, self }:
(import "${pkgs.path}/nixos/tests/make-test-python.nix" ({ ... }: {
  name = "agent-registry-managed-agent";

  nodes.machine = { pkgs, ... }: {
    imports = [ self.nixosModules.default ];

    users.users.tanmay = {
      isNormalUser = true;
      createHome = true;
      home = "/home/tanmay";
      packages = [
        pkgs.tmux
        (pkgs.writeShellScriptBin "agent-wrapper" ''
          set -eu
          cmd="$1"
          shift
          if [ -n "${TMUX_PANE:-}" ] && [ -n "${SUGGESTED_AGENT_NAME:-}" ]; then
            tmux set-option -p -t "$TMUX_PANE" @agent_name "$SUGGESTED_AGENT_NAME"
            tmux select-pane -t "$TMUX_PANE" -T "$SUGGESTED_AGENT_NAME"
          fi
          exec "$cmd" "$@"
        '')
        (pkgs.writeShellScriptBin "pi" ''
          exec sleep 300
        '')
      ];
    };

    services.agent-registry = {
      enable = true;
      auth = false;
      managedAgents.nixos-expert = {
        user = "tanmay";
        session = "nix-homelab-config";
        cwd = "~";
        command = "pi";
        intervalSeconds = 60;
      };
    };
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("agent-registry.service")
    machine.wait_for_unit("agent-registry-managed-nixos-expert.timer")

    machine.succeed("systemctl start agent-registry-managed-nixos-expert.service")
    machine.wait_until_succeeds("su - tanmay -c 'tmux has-session -t nix-homelab-config'")
    machine.wait_until_succeeds("su - tanmay -c \"tmux list-panes -t nix-homelab-config -F '#{@agent_name}' | grep -x nixos-expert\"")

    machine.succeed("su - tanmay -c \"pane=\\$(tmux list-panes -t nix-homelab-config -F '#{pane_id} #{@agent_name}' | awk '$2 == \\\"nixos-expert\\\" {print $1; exit}'); tmux kill-pane -t \\\"$pane\\\"\"")
    machine.succeed("systemctl start agent-registry-managed-nixos-expert.service")
    machine.wait_until_succeeds("su - tanmay -c \"tmux list-panes -t nix-homelab-config -F '#{@agent_name}' | grep -x nixos-expert\"")
  '';
}))
