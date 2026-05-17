{
  description = "Standalone agent-registry";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));
      mkBundle = pkgs:
        let
          registryServer = pkgs.writeShellApplication {
            name = "agent-registry";
            runtimeInputs = [ pkgs.python3 ];
            text = ''exec python3 ${./server.py} "$@"'';
          };
          managedAgent = pkgs.writeShellApplication {
            name = "agent-registry-managed-agent";
            runtimeInputs = [ pkgs.python3 pkgs.tmux pkgs.coreutils pkgs.procps pkgs.bash ];
            text = ''exec python3 ${./managed_agent.py} "$@"'';
          };
        in pkgs.symlinkJoin {
          name = "agent-registry-bundle";
          paths = [ registryServer managedAgent ];
        };
    in {
      packages = forAllSystems (pkgs: {
        default = mkBundle pkgs;
      });
      apps = forAllSystems (pkgs: {
        default = { type = "app"; program = "${self.packages.${pkgs.system}.default}/bin/agent-registry"; };
      });
      checks = forAllSystems (pkgs:
        pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
          managed-agent = import ./managed-agent-test.nix { inherit pkgs self; };
        });
      nixosModules.default = import ./module.nix self;
    };
}
