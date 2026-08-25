{ lib, theme, ... }:
let
  inherit (theme) colors effects geometry;
  stripHash = lib.removePrefix "#";
  rgb = color: "rgb(${stripHash color})";
  activeBorder = lib.generators.mkLuaInline ''
    {
      colors = {
        "rgba(${stripHash colors.accent}ee)",
        "rgba(${stripHash colors.foreground}ee)",
      },
      angle = 45,
    }
  '';
in
{
  wayland.windowManager.hyprland.settings = {
    config = {
      general = {
        border_size = geometry.borderWidth;
        col = {
          active_border = activeBorder;
          inactive_border = rgb colors.backgroundDarker;
        };
      };

      group.col = {
        border_active = activeBorder;
        border_inactive = rgb colors.backgroundDarker;
      };

      decoration = {
        rounding = geometry.radiusSmall;
        rounding_power = 3;
        blur = {
          enabled = effects.blur;
          size = effects.blurSize;
          passes = effects.blurPasses;
          new_optimizations = true;
          xray = false;
        };
        shadow = {
          enabled = effects.shadow;
          range = 12;
          render_power = 3;
          color = "rgba(00000055)";
        };
      };
    };

    layer_rule = [
      {
        match.namespace = "^solitude-(audio|bar|bluetooth|calendar|display|keybinds|launcher|media|network|notification-popup|notifications|osd|system|wallpaper-picker)$";
        blur = effects.blur;
        blur_popups = effects.blur;
        ignore_alpha = 0.15;
      }
    ];
  };
}
