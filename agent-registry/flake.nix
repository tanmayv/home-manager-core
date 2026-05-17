{
  description = "Standalone agent-registry";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));
    in {
      packages = forAllSystems (pkgs: {
        default = pkgs.writeShellApplication {
          name = "agent-registry";
          runtimeInputs = [ pkgs.python3 ];
          text = ''exec python3 ${./server.py} "$@"'';
        };
      });
      apps = forAllSystems (pkgs: {
        default = { type = "app"; program = "${self.packages.${pkgs.system}.default}/bin/agent-registry"; };
      });
      nixosModules.default = import ./module.nix self;
    };
}
