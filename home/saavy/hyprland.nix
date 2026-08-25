{ lib, ... }:
let
  lua = lib.generators.mkLuaInline;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;
    configType = "lua";
    systemd.enable = false;

    settings = {
      config.input = {
        kb_layout = "us";
        follow_mouse = 1;
      };

      bind = [
        {
          _args = [
            "SUPER + Q"
            (lua "hl.dsp.exec_cmd(\"ghostty\")")
          ];
        }
        {
          _args = [
            "SUPER + C"
            (lua "hl.dsp.window.close()")
          ];
        }
        {
          _args = [
            "SUPER + M"
            (lua "hl.dsp.exit()")
          ];
        }
      ];
    };
  };
}
