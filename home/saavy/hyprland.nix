{ lib, ... }:
let
  lua = lib.generators.mkLuaInline;

  focusBinds = map
    ({ key, direction }: {
      _args = [
        "SUPER + ${key}"
        (lua "hl.dsp.focus({ direction = \"${direction}\" })")
      ];
    })
    [
      { key = "LEFT"; direction = "l"; }
      { key = "RIGHT"; direction = "r"; }
      { key = "UP"; direction = "u"; }
      { key = "DOWN"; direction = "d"; }
    ];

  workspaceBinds = lib.concatMap
    ({ key, workspace }: [
      {
        _args = [
          "SUPER + ${key}"
          (lua "hl.dsp.focus({ workspace = \"${workspace}\" })")
        ];
      }
      {
        _args = [
          "SUPER + SHIFT + ${key}"
          (lua "hl.dsp.window.move({ workspace = \"${workspace}\" })")
        ];
      }
    ])
    [
      { key = "1"; workspace = "1"; }
      { key = "2"; workspace = "2"; }
      { key = "3"; workspace = "3"; }
      { key = "4"; workspace = "4"; }
      { key = "5"; workspace = "5"; }
      { key = "6"; workspace = "6"; }
      { key = "7"; workspace = "7"; }
      { key = "8"; workspace = "8"; }
      { key = "9"; workspace = "9"; }
      { key = "0"; workspace = "10"; }
    ];
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;
    configType = "lua";
    systemd.enable = false;

    settings = {
      config = {
        general.layout = "dwindle";
        dwindle.preserve_split = true;
        input = {
          kb_layout = "us";
          follow_mouse = 1;
        };
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
        {
          _args = [
            "SUPER + V"
            (lua "hl.dsp.window.float({ action = \"toggle\" })")
          ];
        }
        {
          _args = [
            "SUPER + F"
            (lua "hl.dsp.window.fullscreen({ mode = \"fullscreen\", action = \"toggle\" })")
          ];
        }
        {
          _args = [
            "SUPER + mouse:272"
            (lua "hl.dsp.window.drag()")
            { mouse = true; }
          ];
        }
        {
          _args = [
            "SUPER + mouse:273"
            (lua "hl.dsp.window.resize()")
            { mouse = true; }
          ];
        }
      ]
      ++ focusBinds
      ++ workspaceBinds;
    };
  };
}
