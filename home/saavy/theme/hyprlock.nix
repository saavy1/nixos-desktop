{ lib, theme, ... }:
let
  inherit (theme) colors;
  rgb = color: "rgb(${lib.removePrefix "#" color})";
in
{
  programs.hyprlock.settings = {
    background = [
      {
        monitor = "";
        color = rgb colors.background;
        blur_passes = 0;
      }
    ];

    input-field = [
      {
        monitor = "";
        size = "400, 60";
        position = "0, 0";
        halign = "center";
        valign = "center";
        inner_color = rgb colors.backgroundDark;
        outer_color = rgb colors.accent;
        font_color = rgb colors.foreground;
        check_color = rgb colors.success;
        fail_color = rgb colors.error;
        outline_thickness = 2;
        placeholder_text = "Enter password";
        fail_text = "$FAIL ($ATTEMPTS)";
        rounding = 6;
        fade_on_empty = false;
      }
    ];
  };
}
