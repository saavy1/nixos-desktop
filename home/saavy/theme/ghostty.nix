{ lib, theme, ... }:
let
  inherit (theme) color typography;
  stripHash = lib.removePrefix "#";
  terminalPalette = lib.imap0 (index: color: "${toString index}=${color}") theme.terminal;
in
{
  programs.ghostty = {
    settings = {
      theme = theme.name;
      font-family = typography.code;
      font-size = typography.size.code;
    };
    themes.${theme.name} = {
      palette = terminalPalette;
      background = stripHash color.surface.base;
      foreground = stripHash color.text.base;
      cursor-color = stripHash color.accent;
      selection-background = stripHash color.surface.hover;
      selection-foreground = stripHash color.text.base;
    };
  };
}
