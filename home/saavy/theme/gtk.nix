{
  lib,
  pkgs,
  theme,
  ...
}:
let
  inherit (theme) color;
  pkgAt = path: lib.getAttrFromPath (lib.splitString "." path) pkgs;

  # libadwaita's named colors. adw-gtk3 reads the same names, so GTK3 and
  # GTK4 apps share one palette.
  namedColors = ''
    @define-color accent_color ${color.accent};
    @define-color accent_bg_color ${color.accent};
    @define-color accent_fg_color ${color.accentText};
    @define-color destructive_color ${color.danger};
    @define-color destructive_bg_color ${color.danger};
    @define-color destructive_fg_color ${color.surface.base};
    @define-color success_color ${color.success};
    @define-color success_bg_color ${color.success};
    @define-color success_fg_color ${color.surface.base};
    @define-color warning_color ${color.warning};
    @define-color warning_bg_color ${color.warning};
    @define-color warning_fg_color ${color.surface.base};
    @define-color error_color ${color.danger};
    @define-color error_bg_color ${color.danger};
    @define-color error_fg_color ${color.surface.base};
    @define-color window_bg_color ${color.surface.base};
    @define-color window_fg_color ${color.text.base};
    @define-color view_bg_color ${color.surface.sunk};
    @define-color view_fg_color ${color.text.base};
    @define-color headerbar_bg_color ${color.surface.base};
    @define-color headerbar_fg_color ${color.text.base};
    @define-color headerbar_border_color ${color.lineSolid};
    @define-color headerbar_backdrop_color ${color.surface.base};
    @define-color sidebar_bg_color ${color.surface.sunk};
    @define-color sidebar_fg_color ${color.text.base};
    @define-color sidebar_backdrop_color ${color.surface.sunk};
    @define-color secondary_sidebar_bg_color ${color.surface.deep};
    @define-color secondary_sidebar_fg_color ${color.text.base};
    @define-color card_bg_color ${color.surface.raised};
    @define-color card_fg_color ${color.text.base};
    @define-color dialog_bg_color ${color.surface.raised};
    @define-color dialog_fg_color ${color.text.base};
    @define-color popover_bg_color ${color.surface.raised};
    @define-color popover_fg_color ${color.text.base};
    @define-color thumbnail_bg_color ${color.surface.raised};
    @define-color thumbnail_fg_color ${color.text.base};
  '';
in
{
  gtk = {
    enable = true;
    font = {
      name = theme.typography.sans;
      size = theme.typography.size.gtk;
    };
    theme = {
      inherit (theme.gtk) name;
      package = pkgAt theme.gtk.package;
    };
    iconTheme = {
      name = theme.icons.name;
      package = pkgs.yaru-theme;
    };
    gtk3 = {
      extraConfig.gtk-application-prefer-dark-theme = 1;
      extraCss = namedColors;
    };
    gtk4 = {
      extraConfig.gtk-application-prefer-dark-theme = 1;
      extraCss = namedColors;
    };
  };

  home.pointerCursor = {
    enable = true;
    inherit (theme.cursor) name size;
    package = pkgAt theme.cursor.package;
    gtk.enable = true;
    hyprcursor.enable = true;
  };

  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
}
