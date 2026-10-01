{ lib, theme, ... }:
let
  inherit (theme)
    color
    geometry
    typography
    wallpaper
    ;
  hex = lib.removePrefix "#";
  rgb = c: "rgb(${hex c})";
  rgba = c: alpha: "rgba(${hex c}${alpha})";
in
{
  programs.hyprlock.settings = {
    background = [
      {
        monitor = "";
        path = "${wallpaper.path}";
        color = rgb color.surface.base;
        blur_passes = 3;
        blur_size = 8;
        brightness = 0.55;
      }
    ];

    label = [
      {
        monitor = "";
        text = ''cmd[update:1000] date +"%H:%M"'';
        color = rgb color.text.base;
        font_family = typography.mono;
        font_size = 96;
        position = "0, 160";
        halign = "center";
        valign = "center";
      }
      {
        monitor = "";
        text = ''cmd[update:60000] date +"%A, %B %-d"'';
        color = rgb color.text.soft;
        font_family = typography.display;
        font_size = 24;
        position = "0, 70";
        halign = "center";
        valign = "center";
      }
    ];

    input-field = [
      {
        monitor = "";
        size = "360, 52";
        position = "0, -40";
        halign = "center";
        valign = "center";
        inner_color = rgba color.surface.base "e6";
        outer_color = rgba color.line "40";
        font_color = rgb color.text.base;
        font_family = typography.sans;
        check_color = rgb color.accent;
        fail_color = rgb color.danger;
        capslock_color = rgb color.warning;
        outline_thickness = 1;
        dots_size = 0.22;
        dots_spacing = 0.4;
        placeholder_text = ''<span foreground="##${hex color.text.faint}">Password</span>'';
        fail_text = "$FAIL ($ATTEMPTS)";
        rounding = geometry.radius.medium;
        fade_on_empty = false;
        shadow_passes = 0;
      }
    ];
  };
}
