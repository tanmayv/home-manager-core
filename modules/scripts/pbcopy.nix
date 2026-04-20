{ pkgs, ... }:

{
  home.packages = [
    (pkgs.writeShellApplication {
      name = "pbcopy";
      runtimeInputs = with pkgs; [
        tmux
        coreutils
        bash
      ];

      text = ''
        # Read from stdin and write to tmux buffer + system clipboard
        input=$(cat)
        tmux set-buffer -w "$input"
      '';
    })
  ];
}
