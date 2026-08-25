{ lib, theme, ... }:
let
  lua = lib.generators.mkLuaInline;
  inherit (theme) colors;
  rgb = color: "rgb(${lib.removePrefix "#" color})";

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
        general = {
          layout = "dwindle";
          border_size = 1;
          col = {
            active_border = rgb colors.accent;
            inactive_border = rgb colors.backgroundDarker;
          };
        };
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
            "SUPER + P"
            (lua ''
              function()
                local window = hl.get_active_window()
                local monitor = hl.get_active_monitor()
                if window == nil or monitor == nil then
                  return
                end

                if window.pinned then
                  hl.dispatch(hl.dsp.window.pin())
                  if window.floating then
                    hl.dispatch(hl.dsp.window.float({ action = "unset" }))
                  end
                  return
                end

                if not window.floating then
                  hl.dispatch(hl.dsp.window.float({ action = "set" }))
                end

                local width = 640
                local height = 360
                local margin = 20
                local x = monitor.x + math.floor(monitor.width / monitor.scale) - width - margin
                local y = monitor.y + math.floor(monitor.height / monitor.scale) - height - margin

                hl.dispatch(hl.dsp.window.resize({
                  x = width,
                  y = height,
                  relative = false,
                }))
                hl.dispatch(hl.dsp.window.move({
                  x = x,
                  y = y,
                  relative = false,
                }))
                hl.dispatch(hl.dsp.window.pin())
              end
            '')
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
            "SUPER + SPACE"
            (lua "hl.dsp.exec_cmd(\"hyprlauncher --toggle\")")
          ];
        }
        {
          _args = [
            "SUPER + E"
            (lua "hl.dsp.exec_cmd(\"ghostty -e yazi\")")
          ];
        }
        {
          _args = [
            "SUPER + V"
            (lua "hl.dsp.exec_cmd(\"clipboard-picker\")")
          ];
        }
        {
          _args = [
            "SUPER + G"
            (lua "hl.dsp.exec_cmd(\"hyprshot -m region --clipboard-only\")")
          ];
        }
        {
          _args = [
            "PRINT"
            (lua "hl.dsp.exec_cmd(\"hyprshot -m region -o $HOME/Pictures\")")
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
