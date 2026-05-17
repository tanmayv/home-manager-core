# agent-registry slice

This slice ships a standalone package/app plus a minimal NixOS module.

The NixOS module can also reconcile local managed agents into tmux sessions on the registry host.
By default those managed agents use a dedicated tmux socket under `~/.cache/agent-registry/tmux.sock`; override `tmuxSocketPath` if you want to share your normal tmux server.
See `AGENT_REGISTRY_DEPLOYMENT.md` for the `managedAgents` example and restart-warning behavior.

Managed-agent end-to-end check:

- `nix build .#checks.x86_64-linux.managed-agent --no-link -L`

Deferred to follow-up: persistence/state path handling, DELETE /trackers, cross-tracker POST /messages, and broader Home Manager integration.
