{ pkgs, inputs, lib, ... }:

{
  home.packages = [ pkgs.neovim ];

  home.sessionVariables = {
    EDITOR = "nvim";
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
