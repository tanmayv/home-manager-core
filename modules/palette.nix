{ userSettings ? {} }:

let
  theme = userSettings.theme or "tokyonight";

  palettes = {
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
  };
in
palettes.${theme} or palettes.tokyonight
