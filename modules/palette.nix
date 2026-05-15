{ userSettings ? {} }:

let
  theme = userSettings.theme or "tokyonight";

  palettes = rec {
    tokyonight = {
      background = "#1a1b26";
      foreground = "#c0caf5";
      cursorColor = "#c0caf5";
      cursorText = "#15161e";
      selectionBackground = "#33467c";
      selectionForeground = "#c0caf5";

      color0 = "#15161e";
      color1 = "#f7768e";
      color2 = "#9ece6a";
      color3 = "#e0af68";
      color4 = "#7aa2f7";
      color5 = "#bb9af7";
      color6 = "#7dcfff";
      color7 = "#a9b1d6";
      color8 = "#414868";
      color9 = "#f7768e";
      color10 = "#9ece6a";
      color11 = "#e0af68";
      color12 = "#7aa2f7";
      color13 = "#bb9af7";
      color14 = "#7dcfff";
      color15 = "#c0caf5";
    };

    everforest = {
      # Everforest Dark Hard Palette
      background = "#272e33";
      foreground = "#d3c6aa";
      cursorColor = "#d3c6aa";
      cursorText = "#272e33";
      selectionBackground = "#445055";
      selectionForeground = "#d3c6aa";

      color0 = "#272e33";  # black
      color1 = "#e67e80";  # red
      color2 = "#a7c080";  # green
      color3 = "#dbbc7f";  # yellow
      color4 = "#7fbbb3";  # blue
      color5 = "#d699b6";  # magenta
      color6 = "#83c092";  # cyan
      color7 = "#d3c6aa";  # white
      color8 = "#475258";  # bright black (grey)
      color9 = "#e67e80";  # bright red
      color10 = "#a7c080"; # bright green
      color11 = "#dbbc7f"; # bright yellow
      color12 = "#7fbbb3"; # bright blue
      color13 = "#d699b6"; # bright magenta
      color14 = "#83c092"; # bright cyan
      color15 = "#d3c6aa"; # bright white
    };

    gruvbox-dark = {
      # Gruvbox Dark Hard Palette
      background = "#1d2021";
      foreground = "#ebdbb2";
      cursorColor = "#ebdbb2";
      cursorText = "#1d2021";
      selectionBackground = "#504945";
      selectionForeground = "#ebdbb2";

      color0 = "#1d2021";  # black
      color1 = "#cc241d";  # red
      color2 = "#98971a";  # green
      color3 = "#d79921";  # yellow
      color4 = "#458588";  # blue
      color5 = "#b16286";  # magenta
      color6 = "#689d6a";  # cyan
      color7 = "#a89984";  # white
      color8 = "#928374";  # bright black (grey)
      color9 = "#fb4934";  # bright red
      color10 = "#b8bb26"; # bright green
      color11 = "#fabd2f"; # bright yellow
      color12 = "#83a598"; # bright blue
      color13 = "#d3869b"; # bright magenta
      color14 = "#8ec07c"; # bright cyan
      color15 = "#ebdbb2"; # bright white
    };

    catppuccin-latte = {
      # Catppuccin Latte Palette — pleasant light theme with good contrast.
      background = "#eff1f5";
      foreground = "#4c4f69";
      cursorColor = "#4c4f69";
      cursorText = "#eff1f5";
      selectionBackground = "#ccd0da";
      selectionForeground = "#4c4f69";

      color0 = "#5c5f77";  # black
      color1 = "#d20f39";  # red
      color2 = "#40a02b";  # green
      color3 = "#df8e1d";  # yellow
      color4 = "#1e66f5";  # blue
      color5 = "#ea76cb";  # magenta
      color6 = "#179299";  # cyan
      color7 = "#acb0be";  # white
      color8 = "#6c6f85";  # bright black (grey)
      color9 = "#d20f39";  # bright red
      color10 = "#40a02b"; # bright green
      color11 = "#df8e1d"; # bright yellow
      color12 = "#1e66f5"; # bright blue
      color13 = "#ea76cb"; # bright magenta
      color14 = "#179299"; # bright cyan
      color15 = "#bcc0cc"; # bright white
    };

    gruvbox = gruvbox-dark;
  };
in
palettes.${theme} or palettes.tokyonight
