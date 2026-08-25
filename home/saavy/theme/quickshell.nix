{ theme, ... }:
let
  inherit (theme)
    colors
    effects
    geometry
    shell
    typography
    wallpaper
    ;
  wallpaperPaths = if wallpaper.paths != [ ] then wallpaper.paths else [ wallpaper.path ];
  wallpaperSources = builtins.concatStringsSep ", " (map (path: ''"file://${path}"'') wallpaperPaths);
in
{
  xdg.configFile."quickshell/desktop/Theme.qml".text = ''
    pragma Singleton

    import QtQuick

    QtObject {
      readonly property color background: "${colors.background}"
      readonly property color backgroundDark: "${colors.backgroundDark}"
      readonly property color backgroundDarker: "${colors.backgroundDarker}"
      readonly property color selection: "${colors.selection}"
      readonly property color border: "${colors.border}"
      readonly property color muted: "${colors.muted}"
      readonly property color accent: "${colors.accent}"
      readonly property color foreground: "${colors.foreground}"
      readonly property color foregroundSoft: "${colors.foregroundSoft}"
      readonly property color warning: "${colors.warning}"
      readonly property color success: "${colors.success}"
      readonly property color error: "${colors.error}"
      readonly property string fontSans: "${typography.sans}"
      readonly property string fontMono: "${typography.mono}"
      readonly property int fontCaption: ${toString typography.size.caption}
      readonly property int fontBody: ${toString typography.size.body}
      readonly property int fontBar: ${toString typography.size.bar}
      readonly property int fontTitle: ${toString typography.size.title}
      readonly property int borderWidth: ${toString geometry.borderWidth}
      readonly property int radiusSmall: ${toString geometry.radiusSmall}
      readonly property int radiusMedium: ${toString geometry.radiusMedium}
      readonly property int radiusLarge: ${toString geometry.radiusLarge}
      readonly property int shellGap: ${toString geometry.shellGap}
      readonly property int outerMargin: ${toString geometry.outerMargin}
      readonly property real panelOpacity: ${toString effects.panelOpacity}
      readonly property bool blurEnabled: ${if effects.blur then "true" else "false"}
      readonly property bool shadowEnabled: ${if effects.shadow then "true" else "false"}
      readonly property int barHeight: ${toString shell.bar.height}
      readonly property int barTitleWidth: ${toString shell.bar.titleWidth}
      readonly property int launcherWidth: ${toString shell.launcher.width}
      readonly property int launcherHeight: ${toString shell.launcher.height}
      readonly property int launcherMaxResults: ${toString shell.launcher.maxResults}
      readonly property int keybindsWidth: ${toString shell.keybinds.width}
      readonly property int keybindsHeight: ${toString shell.keybinds.height}
      readonly property url wallpaperSource: "file://${wallpaper.path}"
      readonly property var wallpaperSources: [${wallpaperSources}]

      function withAlpha(color, opacity) {
        return Qt.rgba(color.r, color.g, color.b, opacity)
      }
    }
  '';
}
