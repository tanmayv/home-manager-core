{ pkgs, inputs, lib, userSettings, ... }:

{
  home.packages = [ pkgs.neovim ];

  home.sessionVariables = {
    EDITOR = userSettings.editor;
  };

  home.activation.copyAstroNvim = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -d ~/.config/nvim ]; then
      echo "Copying AstroNvim template to ~/.config/nvim..."
      mkdir -p ~/.config/nvim
      cp -r ${inputs.astronvim-template}/* ~/.config/nvim/
      chmod -R u+w ~/.config/nvim/
    fi
  '';
}
