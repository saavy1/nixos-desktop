{ pkgs, theme, ... }:
let
  inherit (theme) colors;
in
{
  gtk = {
    enable = true;
    font = {
      name = theme.typography.sans;
      size = theme.typography.size.body;
    };
    iconTheme = {
      name = theme.icons.name;
      package = pkgs.yaru-theme;
    };
    gtk3 = {
      extraConfig.gtk-application-prefer-dark-theme = 1;
      extraCss = ''
        @define-color theme_bg_color ${colors.background};
        @define-color theme_fg_color ${colors.foreground};
        @define-color theme_selected_bg_color ${colors.accent};
        @define-color theme_selected_fg_color ${colors.background};
        @define-color error_color ${colors.error};
        @define-color warning_color ${colors.warning};
        @define-color success_color ${colors.success};
      '';
    };
    gtk4 = {
      extraConfig.gtk-application-prefer-dark-theme = 1;
      extraCss = ''
        @define-color window_bg_color ${colors.background};
        @define-color window_fg_color ${colors.foreground};
        @define-color view_bg_color ${colors.background};
        @define-color view_fg_color ${colors.foreground};
        @define-color accent_bg_color ${colors.accent};
        @define-color accent_fg_color ${colors.background};
        @define-color error_color ${colors.error};
        @define-color warning_color ${colors.warning};
        @define-color success_color ${colors.success};
      '';
    };
  };

  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
}
