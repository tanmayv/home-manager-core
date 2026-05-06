{ pkgs, ... }: {
  home.packages = with pkgs; [
    delta
    difftastic
  ];

  home.file.".hgrc" = {
    text = ''
      [ui]
      ignore = ~/.hgignore
      [extensions]
      extdiff =

      # Optional: Allows using 'hg delta' as an explicit extdiff tool
      # e.g., hg delta -r chain
      [extdiff]
      cmd.delta = delta --dark --paging=never
      cmd.ndiff = nvim
      opts.ndiff = -d
      cmd.cdiff = difft
      opts.cdiff = --color=always

      # Configure hg diff to output git-style diffs, which delta prefers
      [diff]
      git = True

      # Use delta as the pager for hg commands
      [pager]
      pager = delta --dark --paging=never
      attend = diff, log, status, blame, annotate
    '';
  };
  home.file.".hgignore" = {
    text = ''
      syntax: glob
      .envrc
      .git

      *.ignore.txt
      *.ignore.md
      *.ignore.sql
      *.ignore.csv
    '';
  };
}
