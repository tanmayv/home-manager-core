{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "gemini";
      text = ''
        agent-wrapper /google/bin/releases/gemini-cli/tools/gemini "$@"
      '';
    })
    (pkgs.writeShellApplication {
      name = "jetski";
      text = ''
        agent-wrapper /google/bin/releases/jetski-devs/tools/cli "$@"
      '';
    })
  ];
}
