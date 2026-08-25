{ config, pkgs, ... }:
let
  clipboardSelect = pkgs.writeShellApplication {
    name = "clipboard-select";
    runtimeInputs = [
      pkgs.cliphist
      pkgs.wl-clipboard
    ];
    text = ''
      printf '%s' "$1" | cliphist decode | wl-copy
    '';
  };

in
{
  home.packages = [
    clipboardSelect
  ];

  programs.quickshell = {
    enable = true;
    activeConfig = "desktop";
    systemd.enable = true;
  };

  services.cliphist = {
    enable = true;
    systemdTargets = [ "graphical-session.target" ];
  };

  xdg.configFile = {
    "quickshell/desktop/Bar.qml".source = ./quickshell/Bar.qml;
    "quickshell/desktop/AudioPanel.qml".source = ./quickshell/AudioPanel.qml;
    "quickshell/desktop/BindingRow.qml".source = ./quickshell/BindingRow.qml;
    "quickshell/desktop/CalendarPanel.qml".source = ./quickshell/CalendarPanel.qml;
    "quickshell/desktop/Keybinds.qml".source = ./quickshell/Keybinds.qml;
    "quickshell/desktop/Launcher.qml".source = ./quickshell/Launcher.qml;
    "quickshell/desktop/PanelCard.qml".source = ./quickshell/PanelCard.qml;
    "quickshell/desktop/PanelDivider.qml".source = ./quickshell/PanelDivider.qml;
    "quickshell/desktop/PopupController.qml".source = ./quickshell/PopupController.qml;
    "quickshell/desktop/NetworkPanel.qml".source = ./quickshell/NetworkPanel.qml;
    "quickshell/desktop/NotificationStatus.qml".source = ./quickshell/NotificationStatus.qml;
    "quickshell/desktop/Wallpaper.qml".source = ./quickshell/Wallpaper.qml;
    "quickshell/desktop/WallpaperPicker.qml".source = ./quickshell/WallpaperPicker.qml;
    "quickshell/desktop/shell.qml".source = ./quickshell/shell.qml;
  };

  systemd.user.services.quickshell.Unit.X-Restart-Triggers = [
    "${config.xdg.configFile."quickshell/desktop/AudioPanel.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/Bar.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/BindingRow.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/CalendarPanel.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/Keybinds.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/Launcher.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/PanelCard.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/PanelDivider.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/PopupController.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/Theme.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/NetworkPanel.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/NotificationStatus.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/Wallpaper.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/WallpaperPicker.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/shell.qml".source}"
  ];
}
