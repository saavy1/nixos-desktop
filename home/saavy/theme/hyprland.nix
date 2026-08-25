{ lib, theme, ... }:
let
  inherit (theme) colors;
  rgb = color: "rgb(${lib.removePrefix "#" color})";
in
{
  wayland.windowManager.hyprland.settings.config.general = {
    border_size = 1;
    col = {
      active_border = rgb colors.accent;
      inactive_border = rgb colors.backgroundDarker;
    };
  };
}
