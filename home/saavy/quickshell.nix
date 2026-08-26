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
    "quickshell/desktop/AudioPanel.qml".source = ./quickshell/AudioPanel.qml;
    "quickshell/desktop/Bar.qml".source = ./quickshell/Bar.qml;
    "quickshell/desktop/BindingRow.qml".source = ./quickshell/BindingRow.qml;
    "quickshell/desktop/BluetoothPanel.qml".source = ./quickshell/BluetoothPanel.qml;
    "quickshell/desktop/CalendarPanel.qml".source = ./quickshell/CalendarPanel.qml;
    "quickshell/desktop/CapturePanel.qml".source = ./quickshell/CapturePanel.qml;
    "quickshell/desktop/CaptureState.qml".source = ./quickshell/CaptureState.qml;
    "quickshell/desktop/DisplayPanel.qml".source = ./quickshell/DisplayPanel.qml;
    "quickshell/desktop/Keybinds.qml".source = ./quickshell/Keybinds.qml;
    "quickshell/desktop/Launcher.qml".source = ./quickshell/Launcher.qml;
    "quickshell/desktop/MediaPanel.qml".source = ./quickshell/MediaPanel.qml;
    "quickshell/desktop/MediaStatus.qml".source = ./quickshell/MediaStatus.qml;
    "quickshell/desktop/NotificationCard.qml".source = ./quickshell/NotificationCard.qml;
    "quickshell/desktop/NotificationCenter.qml".source = ./quickshell/NotificationCenter.qml;
    "quickshell/desktop/NotificationPopup.qml".source = ./quickshell/NotificationPopup.qml;
    "quickshell/desktop/NotificationState.qml".source = ./quickshell/NotificationState.qml;
    "quickshell/desktop/Osd.qml".source = ./quickshell/Osd.qml;
    "quickshell/desktop/PanelCard.qml".source = ./quickshell/PanelCard.qml;
    "quickshell/desktop/PanelDivider.qml".source = ./quickshell/PanelDivider.qml;
    "quickshell/desktop/PopupController.qml".source = ./quickshell/PopupController.qml;
    "quickshell/desktop/NetworkPanel.qml".source = ./quickshell/NetworkPanel.qml;
    "quickshell/desktop/SystemPanel.qml".source = ./quickshell/SystemPanel.qml;
    "quickshell/desktop/Wallpaper.qml".source = ./quickshell/Wallpaper.qml;
    "quickshell/desktop/WallpaperPicker.qml".source = ./quickshell/WallpaperPicker.qml;
    "quickshell/desktop/shell.qml".source = ./quickshell/shell.qml;
  };

  systemd.user.services.quickshell.Unit.X-Restart-Triggers = [
    "${config.xdg.configFile."quickshell/desktop/AudioPanel.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/Bar.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/BindingRow.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/BluetoothPanel.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/CalendarPanel.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/CapturePanel.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/CaptureState.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/DisplayPanel.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/Keybinds.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/Launcher.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/MediaPanel.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/MediaStatus.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/NotificationCard.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/NotificationCenter.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/NotificationPopup.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/NotificationState.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/Osd.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/PanelCard.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/PanelDivider.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/PopupController.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/Theme.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/NetworkPanel.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/SystemPanel.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/Wallpaper.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/WallpaperPicker.qml".source}"
    "${config.xdg.configFile."quickshell/desktop/shell.qml".source}"
  ];
}
