{ lib, theme, ... }:
let
  inherit (theme) color effects geometry;
  stripHash = lib.removePrefix "#";
  rgb = color: "rgb(${stripHash color})";
  activeBorder = lib.generators.mkLuaInline ''
    {
      colors = {
        "rgba(${stripHash color.accent}ee)",
        "rgba(${stripHash color.secondary}ee)",
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
          inactive_border = rgb color.surface.deep;
        };
      };

      group.col = {
        border_active = activeBorder;
        border_inactive = rgb color.surface.deep;
      };

      decoration = {
        rounding = geometry.radius.small;
        rounding_power = 3;
        blur = {
          enabled = effects.blur;
          size = effects.blurSize;
          passes = effects.blurPasses;
          new_optimizations = true;
          xray = false;
        };
        shadow = {
          enabled = effects.shadow != "none";
          range = 12;
          render_power = 3;
          color = "rgba(${stripHash color.surface.deep}88)";
        };
      };
    };

    layer_rule = [
      {
        match.namespace = "^qs-.*$";
        blur = effects.blur;
        blur_popups = effects.blur;
        ignore_alpha = 0.3;
      }
    ];
  };
}
