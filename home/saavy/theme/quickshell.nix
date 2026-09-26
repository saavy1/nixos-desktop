{ lib, pkgs, theme, ... }:
let
  inherit (theme)
    alpha
    color
    effects
    geometry
    motion
    shell
    spacing
    typography
    wallpaper
    ;
  bool = value: if value then "true" else "false";
  # QML parses "#AARRGGBB"; bake alpha in here so tokens stay plain colors.
  argb =
    hex: opacity:
    let
      byte = lib.toHexString (builtins.floor (opacity * 255 + 0.5));
    in
    "#${lib.fixedWidthString 2 "0" byte}${lib.removePrefix "#" hex}";
  # Name -> glyph map for the icon font, read from its cmap at build time.
  iconsQml =
    pkgs.runCommand "quickshell-icons.qml"
      { nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.fonttools ])) ]; }
      ''
        python3 - ${pkgs.lucide}/share/fonts/truetype/Lucide.ttf > $out <<'PY'
        import json, sys
        from fontTools.ttLib import TTFont
        glyphs = {}
        for codepoint, name in sorted(TTFont(sys.argv[1]).getBestCmap().items()):
            if codepoint >= 0xE000:
                glyphs.setdefault(name, chr(codepoint))
        print("pragma Singleton\n\nimport QtQuick\n\nQtObject {")
        print("  readonly property var glyphs: (" + json.dumps(glyphs, sort_keys=True) + ")")
        print("}")
        PY
      '';

  # Tileable white noise with random alpha, overlaid on panels for grain.
  grain = pkgs.runCommand "quickshell-grain.png" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    magick -size 256x256 -seed 7 xc:gray50 +noise Random -colorspace Gray \
      -alpha copy -fill white -colorize 100 PNG32:$out
  '';

  wallpaperPaths = if wallpaper.paths != [ ] then wallpaper.paths else [ wallpaper.path ];
  wallpaperSources = builtins.concatStringsSep ", " (map (path: ''"file://${path}"'') wallpaperPaths);

  # Renders an attrset as a grouped QtObject: `Theme.<name>.<key>`.
  group =
    type: name: attrs:
    let
      props = lib.mapAttrsToList (
        key: value:
        "readonly property ${type} ${key}: ${
          if type == "color" || type == "string" then ''"${value}"'' else toString value
        }"
      ) attrs;
    in
    # First line is indented by the template; the rest carry their own indent.
    "readonly property QtObject ${name}: QtObject {\n"
    + lib.concatMapStrings (prop: "    ${prop}\n") props
    + "  }";
in
{
  xdg.configFile."quickshell/desktop/Icons.qml".source = iconsQml;

  xdg.configFile."quickshell/desktop/Theme.qml".text = ''
    pragma Singleton

    import QtQuick

    QtObject {
      ${group "color" "surface" color.surface}
      ${group "color" "text" color.text}
      readonly property color line: "${argb color.line alpha.line}"
      readonly property color lineStrong: "${argb color.line alpha.lineStrong}"
      readonly property color lineSolid: "${color.lineSolid}"
      readonly property color hover: "${argb color.line alpha.hover}"
      readonly property color selected: "${argb color.accent alpha.selected}"
      readonly property color scrim: "${argb color.surface.deep alpha.scrim}"
      readonly property color accentText: "${color.accentText}"
      readonly property color secondary: "${color.secondary}"
      readonly property color danger: "${color.danger}"
      readonly property color dangerTint: "${argb color.danger alpha.tint}"
      ${group "real" "alpha" alpha}
      ${group "int" "space" spacing}
      ${group "int" "radius" geometry.radius}
      ${group "int" "motion" motion}
      ${group "int" "fontSize" typography.size}
      readonly property string fontDisplay: "${typography.display}"
      readonly property string fontIcons: "${typography.icons}"
      readonly property real barOpacity: ${toString effects.barOpacity}
      readonly property string shadowStyle: "${effects.shadow}"
      readonly property bool grainEnabled: ${bool effects.grain}
      readonly property real grainOpacity: ${toString effects.grainOpacity}
      readonly property url grainSource: "file://${grain}"

      readonly property color accent: "${color.accent}"
      readonly property color warning: "${color.warning}"
      readonly property color success: "${color.success}"
      readonly property string fontSans: "${typography.sans}"
      readonly property string fontMono: "${typography.mono}"
      readonly property int borderWidth: ${toString geometry.borderWidth}
      readonly property int shellGap: ${toString geometry.shellGap}
      readonly property int outerMargin: ${toString geometry.outerMargin}
      readonly property real panelOpacity: ${toString effects.panelOpacity}
      readonly property int barHeight: ${toString shell.bar.height}
      readonly property int launcherWidth: ${toString shell.launcher.width}
      readonly property int launcherHeight: ${toString shell.launcher.height}
      readonly property int launcherMaxResults: ${toString shell.launcher.maxResults}
      readonly property int keybindsWidth: ${toString shell.keybinds.width}
      readonly property int keybindsHeight: ${toString shell.keybinds.height}
      readonly property url wallpaperSource: "file://${wallpaper.path}"
      readonly property var wallpaperSources: [${wallpaperSources}]

      // Named color tones for Label/Icon: text ramp plus accent and status.
      function tone(name) {
        switch (name) {
        case "soft": return text.soft
        case "faint": return text.faint
        case "disabled": return text.disabled
        case "accent": return accent
        case "accentText": return accentText
        case "danger": return danger
        case "warning": return warning
        case "success": return success
        case "base": return text.base
        default:
          console.warn("Theme.tone: unknown tone " + name)
          return text.base
        }
      }

      function withAlpha(color, opacity) {
        return Qt.rgba(color.r, color.g, color.b, opacity)
      }
    }
  '';
}
