{ lib, ... }:
let
  lua = lib.generators.mkLuaInline;

  focusBinds =
    map
      (
        {
          key,
          direction,
          label,
        }:
        {
          _args = [
            "SUPER + ${key}"
            (lua "hl.dsp.focus({ direction = \"${direction}\" })")
            { description = "Windows · Focus ${label}"; }
          ];
        }
      )
      [
        {
          key = "LEFT";
          direction = "l";
          label = "left";
        }
        {
          key = "RIGHT";
          direction = "r";
          label = "right";
        }
        {
          key = "UP";
          direction = "u";
          label = "up";
        }
        {
          key = "DOWN";
          direction = "d";
          label = "down";
        }
      ];

  workspaceBinds =
    lib.concatMap
      ({ key, workspace }: [
        {
          _args = [
            "SUPER + ${key}"
            (lua "hl.dsp.focus({ workspace = \"${workspace}\" })")
            { description = "Workspaces · Focus ${workspace}"; }
          ];
        }
        {
          _args = [
            "SUPER + SHIFT + ${key}"
            (lua "hl.dsp.window.move({ workspace = \"${workspace}\" })")
            { description = "Workspaces · Move window to ${workspace}"; }
          ];
        }
      ])
      [
        {
          key = "1";
          workspace = "1";
        }
        {
          key = "2";
          workspace = "2";
        }
        {
          key = "3";
          workspace = "3";
        }
        {
          key = "4";
          workspace = "4";
        }
        {
          key = "5";
          workspace = "5";
        }
        {
          key = "6";
          workspace = "6";
        }
        {
          key = "7";
          workspace = "7";
        }
        {
          key = "8";
          workspace = "8";
        }
        {
          key = "9";
          workspace = "9";
        }
        {
          key = "0";
          workspace = "10";
        }
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
      monitor = [
        {
          output = "desc:LG Electronics LG TV SSCR2";
          mode = "3840x2160@120";
          position = "0x0";
          scale = 1;
          bitdepth = 10;
          cm = "auto";
          sdrbrightness = 1.2;
          sdrsaturation = 1.0;
        }
      ];

      config = {
        general.layout = "dwindle";
        dwindle.preserve_split = true;
        render.cm_auto_hdr = 1;
        input = {
          kb_layout = "us";
          follow_mouse = 1;
        };
      };

      animation = [
        {
          leaf = "windows";
          enabled = true;
          speed = 2.5;
          bezier = "default";
          style = "popin 92%";
        }
        {
          leaf = "windowsMove";
          enabled = true;
          speed = 1.5;
          bezier = "default";
        }
        {
          leaf = "layers";
          enabled = true;
          speed = 2;
          bezier = "default";
          style = "fade";
        }
        {
          leaf = "fade";
          enabled = true;
          speed = 1.5;
          bezier = "default";
        }
        {
          leaf = "workspaces";
          enabled = true;
          speed = 2.5;
          bezier = "default";
          style = "slidefade 10%";
        }
      ];

      bind = [
        {
          _args = [
            "SUPER + Q"
            (lua "hl.dsp.exec_cmd(\"ghostty\")")
            { description = "Applications · Terminal"; }
          ];
        }
        {
          _args = [
            "SUPER + C"
            (lua "hl.dsp.window.close()")
            { description = "Windows · Close"; }
          ];
        }
        {
          _args = [
            "SUPER + M"
            (lua "hl.dsp.exit()")
            { description = "Session · Exit Hyprland"; }
          ];
        }
        {
          _args = [
            "SUPER + L"
            (lua "hl.dsp.exec_cmd(\"hyprlock\")")
            { description = "Session · Lock"; }
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
            { description = "Windows · Picture in picture"; }
          ];
        }
        {
          _args = [
            "SUPER + F"
            (lua "hl.dsp.window.fullscreen({ mode = \"fullscreen\", action = \"toggle\" })")
            { description = "Windows · Toggle fullscreen"; }
          ];
        }
        {
          _args = [
            "SUPER + SPACE"
            (lua "hl.dsp.exec_cmd(\"qs -c desktop ipc call launcher toggle\")")
            { description = "Applications · Launcher"; }
          ];
        }
        {
          _args = [
            "SUPER + K"
            (lua "hl.dsp.exec_cmd(\"qs -c desktop ipc call keybinds toggle\")")
            { description = "Help · Keybindings"; }
          ];
        }
        {
          _args = [
            "SUPER + CTRL + A"
            (lua "hl.dsp.exec_cmd(\"qs -c desktop ipc call audio toggle\")")
            { description = "Shell · Audio panel"; }
          ];
        }
        {
          _args = [
            "SUPER + CTRL + W"
            (lua "hl.dsp.exec_cmd(\"qs -c desktop ipc call network toggle\")")
            { description = "Shell · Network panel"; }
          ];
        }
        {
          _args = [
            "SUPER + CTRL + ALT + D"
            (lua "hl.dsp.exec_cmd(\"qs -c desktop ipc call calendar toggle\")")
            { description = "Shell · Calendar panel"; }
          ];
        }
        {
          _args = [
            "SUPER + CTRL + SPACE"
            (lua "hl.dsp.exec_cmd(\"qs -c desktop ipc call wallpaper toggle\")")
            { description = "Shell · Wallpaper picker"; }
          ];
        }
        {
          _args = [
            "SUPER + ESCAPE"
            (lua "hl.dsp.exec_cmd(\"qs -c desktop ipc call system toggle\")")
            { description = "Shell · System menu"; }
          ];
        }
        {
          _args = [
            "SUPER + CTRL + B"
            (lua "hl.dsp.exec_cmd(\"qs -c desktop ipc call bluetooth toggle\")")
            { description = "Shell · Bluetooth panel"; }
          ];
        }
        {
          _args = [
            "SUPER + CTRL + D"
            (lua "hl.dsp.exec_cmd(\"qs -c desktop ipc call display toggle\")")
            { description = "Shell · Display panel"; }
          ];
        }
        {
          _args = [
            "SUPER + CTRL + M"
            (lua "hl.dsp.exec_cmd(\"qs -c desktop ipc call media toggle\")")
            { description = "Shell · Media panel"; }
          ];
        }
        {
          _args = [
            "XF86AudioRaiseVolume"
            (lua "hl.dsp.exec_cmd(\"wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+\")")
            {
              repeating = true;
              locked = true;
              description = "Media · Raise volume";
            }
          ];
        }
        {
          _args = [
            "XF86AudioLowerVolume"
            (lua "hl.dsp.exec_cmd(\"wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-\")")
            {
              repeating = true;
              locked = true;
              description = "Media · Lower volume";
            }
          ];
        }
        {
          _args = [
            "XF86AudioMute"
            (lua "hl.dsp.exec_cmd(\"wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle\")")
            {
              locked = true;
              description = "Media · Toggle output mute";
            }
          ];
        }
        {
          _args = [
            "XF86AudioMicMute"
            (lua "hl.dsp.exec_cmd(\"wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle\")")
            {
              locked = true;
              description = "Media · Toggle microphone mute";
            }
          ];
        }
        {
          _args = [
            "XF86MonBrightnessUp"
            (lua "hl.dsp.exec_cmd(\"brightness-step +5%\")")
            {
              repeating = true;
              locked = true;
              description = "Display · Raise brightness";
            }
          ];
        }
        {
          _args = [
            "XF86MonBrightnessDown"
            (lua "hl.dsp.exec_cmd(\"brightness-step 5%-\")")
            {
              repeating = true;
              locked = true;
              description = "Display · Lower brightness";
            }
          ];
        }
        {
          _args = [
            "XF86AudioPlay"
            (lua "hl.dsp.exec_cmd(\"qs -c desktop ipc call media playPause\")")
            {
              locked = true;
              description = "Media · Play or pause";
            }
          ];
        }
        {
          _args = [
            "XF86AudioNext"
            (lua "hl.dsp.exec_cmd(\"qs -c desktop ipc call media next\")")
            {
              locked = true;
              description = "Media · Next track";
            }
          ];
        }
        {
          _args = [
            "XF86AudioPrev"
            (lua "hl.dsp.exec_cmd(\"qs -c desktop ipc call media previous\")")
            {
              locked = true;
              description = "Media · Previous track";
            }
          ];
        }
        {
          _args = [
            "SUPER + E"
            (lua "hl.dsp.exec_cmd(\"ghostty -e yazi\")")
            { description = "Applications · File manager"; }
          ];
        }
        {
          _args = [
            "SUPER + V"
            (lua "hl.dsp.exec_cmd(\"qs -c desktop ipc call launcher clipboard\")")
            { description = "Applications · Clipboard history"; }
          ];
        }
        {
          _args = [
            "SUPER + G"
            (lua "hl.dsp.exec_cmd(\"hyprshot -m region --clipboard-only && qs -c desktop ipc call osd screenshotCopied\")")
            { description = "Capture · Region to clipboard"; }
          ];
        }
        {
          _args = [
            "PRINT"
            (lua "hl.dsp.exec_cmd(\"hyprshot -m region -o $HOME/Pictures && qs -c desktop ipc call osd screenshotSaved $HOME/Pictures\")")
            { description = "Capture · Region to file"; }
          ];
        }
        {
          _args = [
            "SUPER + mouse:272"
            (lua "hl.dsp.window.drag()")
            {
              mouse = true;
              description = "Windows · Move with mouse";
            }
          ];
        }
        {
          _args = [
            "SUPER + mouse:273"
            (lua "hl.dsp.window.resize()")
            {
              mouse = true;
              description = "Windows · Resize with mouse";
            }
          ];
        }
      ]
      ++ focusBinds
      ++ workspaceBinds;
    };
  };
}
