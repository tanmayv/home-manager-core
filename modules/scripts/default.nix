{ pkgs, ... }:

{
  imports = [
    ./fuse_fix.nix
    ./build-and-switch.nix
    ./iamdone.nix
    ./waiting.nix
    ./send-message-to-agent.nix
    ./tmux-cs-fzf.nix
    ./knowledge-manager.nix
    ./agent-wrapper.nix
  ];
}
