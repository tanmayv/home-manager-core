# Agent Registry Deployment Guide

This guide shows how to run `agent-registry` as a standalone service, how to configure shared-secret auth, and how to intentionally disable auth for local/dev setups.

## What this slice ships

The registry flake exports:

- `packages.<system>.default`
- `apps.<system>.default`
- `nixosModules.default`

Files:

- `agent-registry/server.py` — registry server
- `agent-registry/flake.nix` — standalone flake entrypoint
- `agent-registry/module.nix` — minimal NixOS module

## 1. Standalone registry deployment on NixOS

### Flake input wiring

In your `flake.nix`:

```nix
{
  inputs.agent-registry.url = "path:/path/to/home-manager-core/agent-registry";

  outputs = { self, nixpkgs, agent-registry, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        agent-registry.nixosModules.default
        ./hosts/my-host.nix
      ];
    };
  };
}
```

Then in a normal NixOS module such as `hosts/my-host.nix`:

```nix
{ ... }: {
  services.agent-registry = {
    enable = true;
    port = 8080;
    auth = true;
    tokenFile = "/run/secrets/agent-registry-token";
    staleSeconds = 60;
    goneSeconds = 180;
  };
}
```

Then rebuild normally:

```bash
sudo nixos-rebuild switch --flake .#my-host
```

## 2. Running the app directly

For quick manual runs:

```bash
nix run path:/path/to/home-manager-core/agent-registry
```

Optional environment:

```bash
export AGENT_REGISTRY_PORT=8080
export TRACKER_STALE_SECONDS=60
export TRACKER_GONE_SECONDS=180
export AGENT_REGISTRY_AUTH=true
export AGENT_REGISTRY_TOKEN="your-shared-token"
nix run path:/path/to/home-manager-core/agent-registry
```

## 3. Secret setup when auth is enabled

When `services.agent-registry.auth = true`, you must provide `services.agent-registry.tokenFile`.

Example token creation:

```bash
umask 077
openssl rand -base64 32 > /run/secrets/agent-registry-token
```

Recommended properties:

- readable only by root/service manager
- not committed to git
- not stored in the Nix store

The module reads the token at runtime and exports it to the service process as `AGENT_REGISTRY_TOKEN`.

## 4. Disable auth / secrets intentionally

For local development or trusted test environments, you can disable auth entirely:

```nix
services.agent-registry = {
  enable = true;
  auth = false;
  port = 8080;
};
```

When `auth = false`:

- `tokenFile` is not required
- the registry accepts unauthenticated requests on non-`/healthz` endpoints
- this should only be used for local/dev or otherwise trusted networks

## 5. Tracker-side configuration

Trackers do **not** talk to the registry unless `registryUrl` is set.

Home Manager tracker options added by this slice:

```nix
services.agent-tracker = {
  enable = true;
  httpPort = 19876;

  # Enable registry integration
  registryUrl = "http://agent-registry.example:8080";

  # Auth defaults to false so existing local-only setups keep working.
  registryAuth = true;
  registryTokenFile = "/run/secrets/agent-registry-token";

  registryHeartbeatSeconds = 30;
};
```

### Tracker secret setup

Create the same shared token file on tracker machines.

**Important:** `services.agent-tracker` runs as the user, not as root. So `registryTokenFile` must point to a file readable by that user. A root-only `/run/secrets/...` path is usually **not** correct for the tracker unless you separately arrange user-readable secret material.

Example user-readable path:

```bash
mkdir -p ~/.config/agent-tracker
umask 077
printf '%s' 'your-shared-token' > ~/.config/agent-tracker/registry-token
```

Then configure:

```nix
services.agent-tracker.registryTokenFile = "/home/your-user/.config/agent-tracker/registry-token";
```

When `registryAuth = true`, `registryTokenFile` is required.
The tracker daemon reads the token file at runtime and exports `AGENT_REGISTRY_TOKEN` without embedding the secret in the Nix store.

After changing tracker-side Home Manager options, apply them with your normal Home Manager workflow, for example:

```bash
build-and-switch
```

Or equivalently:

```bash
home-manager switch
```

### Disable tracker auth intentionally

For local/dev testing against a registry with auth disabled:

```nix
services.agent-tracker = {
  enable = true;
  registryUrl = "http://127.0.0.1:8080";
  registryAuth = false;
};
```

This leaves local-only agent-tracker usage unaffected and avoids secret setup.

## 6. Minimal end-to-end dev setup

Registry host:

```nix
services.agent-registry = {
  enable = true;
  auth = false;
  port = 8080;
};
```

Tracker host:

```nix
services.agent-tracker = {
  enable = true;
  registryUrl = "http://registry-host:8080";
  registryAuth = false;
};
```

## 7. Notes / current slice scope

This deployment guide reflects the current vertical slice.
Deferred follow-up items include:

- persistence/state file handling
- `DELETE /trackers`
- cross-tracker `POST /messages`
- broader Home Manager integration for the registry service itself
