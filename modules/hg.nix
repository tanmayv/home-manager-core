{ ... }: {
  home.file.".hgrc" = {
    text = ''
      [ui]
      ignore = ~/.hgignore
      [extensions]
      extdiff =
      [extdiff]
      cmd.nvimdiff = nvim
      opts.nvimdiff = -d
      # You can add default options here if needed
      # opts.nvimdiff =
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
