{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "pbpaste";
      runtimeInputs = with pkgs; [
        tmux
        coreutils
        bash
      ];

      text = ''
        # Read from tmux buffer and write to stdout
        tmux save-buffer -
      '';
    })
  ];
}
