{ pkgs, lib, ... }:

{
  home.packages = [ pkgs.neovim ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  xdg.configFile = lib.mkMerge [
    # 1. Base configuration (always applied)
    {
      "nvim/lua/plugins/nix-integration.lua".text = ''
        return {
          "nix-integration-dummy-name",
          dir = vim.fn.stdpath("config"),
          lazy = false,
          priority = 1000, -- High priority to ensure it loads first
          config = function()
            vim.g.sqlite_clib_path = "${pkgs.sqlite.out}/lib/libsqlite3${pkgs.stdenv.hostPlatform.extensions.sharedLibrary}"
          end,
        }
      '';
      "nvim" = { source = ./dotfiles/nvim; recursive = true; };
    }
  ];
}
