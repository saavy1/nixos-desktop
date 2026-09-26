{
  config,
  lib,
  theme,
  ...
}:
let
  inherit (theme) color typography;
  argb = hex: "#ff${lib.removePrefix "#" hex}";

  # QPalette roles in qt5ct/qt6ct order: WindowText, Button, Light, Midlight,
  # Dark, Mid, Text, BrightText, ButtonText, Base, Window, Shadow, Highlight,
  # HighlightedText, Link, LinkVisited, AlternateBase, NoRole, ToolTipBase,
  # ToolTipText, PlaceholderText.
  palette =
    text: soft:
    lib.concatMapStringsSep ", " argb [
      text
      color.surface.raised
      color.surface.hover
      color.surface.raised
      color.surface.deep
      color.lineSolid
      text
      color.accent
      text
      color.surface.sunk
      color.surface.base
      color.surface.deep
      color.accent
      color.accentText
      color.secondary
      color.warning
      color.surface.base
      color.surface.base
      color.surface.raised
      text
      soft
    ];

  colorScheme = ''
    [ColorScheme]
    active_colors=${palette color.text.base color.text.disabled}
    inactive_colors=${palette color.text.base color.text.disabled}
    disabled_colors=${palette color.text.disabled color.text.disabled}
  '';

  schemePath = name: "${config.xdg.configHome}/${name}/colors/${theme.name}.conf";

  settings = name: fontSpec: {
    Appearance = {
      custom_palette = true;
      color_scheme_path = schemePath name;
      style = "Fusion";
      icon_theme = theme.icons.name;
      standard_dialogs = "xdgdesktopportal";
    };
    Fonts = {
      general = fontSpec typography.sans;
      fixed = fontSpec typography.mono;
    };
  };
in
{
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    qt5ctSettings = settings "qt5ct" (family: ''"${family},${toString typography.size.gtk},-1,5,50,0,0,0,0,0"'');
    qt6ctSettings = settings "qt6ct" (
      family: ''"${family},${toString typography.size.gtk},-1,5,400,0,0,0,0,0,0,0,0,0,0,1"''
    );
  };

  xdg.configFile = {
    "qt5ct/colors/${theme.name}.conf".text = colorScheme;
    "qt6ct/colors/${theme.name}.conf".text = colorScheme;
  };
}
