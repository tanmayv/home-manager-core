{ pkgs, username, ... }: {
  imports = [
    ./modules/zsh.nix
    ./modules/tmux.nix
    ./modules/test.nix
    ./modules/neovim/default.nix
  ];

  home.username = username;
  home.homeDirectory = "/usr/local/google/home/${username}";
  home.stateVersion = "23.11";

  programs.home-manager.enable = true;

  # Required for Home Manager to setup environment variables on non-NixOS Linux
  targets.genericLinux.enable = true;

  # Tokyo Night Theme via Stylix
  stylix = {
    enable = true;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-night-dark.yaml";
    
    # Required field, using a built-in NixOS/Gnome background to avoid network issues
    image = "${pkgs.gnome-backgrounds}/share/backgrounds/gnome/adwaita-d.jxl";
    
    polarity = "dark";

    # Disable GUI-related targets since this is a CLI-only configuration
    targets = {
      gtk.enable = false;
      xresources.enable = false;
    };
    
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };
      sizes = {
        applications = 12;
        terminal = 12;
        desktop = 10;
        popups = 10;
      };
    };
  };

  # You can customize the status bar position here
  programs.tmux.statusBarPosition = "bottom";

  home.packages = with pkgs; [
    fzf
    ripgrep
    pure-prompt
  ];
}
