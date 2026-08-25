{ lib, theme, ... }:
let
  inherit (theme) colors;
  stripHash = lib.removePrefix "#";
  terminalPalette = lib.imap0 (index: color: "${toString index}=${color}") theme.terminal;
in
{
  programs.ghostty = {
    settings.theme = theme.name;
    themes.${theme.name} = {
      palette = terminalPalette;
      background = stripHash colors.background;
      foreground = stripHash colors.foreground;
      cursor-color = stripHash colors.accent;
      selection-background = stripHash colors.selection;
      selection-foreground = stripHash colors.foreground;
    };
  };
}
