{ lib, theme, ... }:
let
  inherit (theme) colors;
  stripHash = lib.removePrefix "#";
  terminalPalette = lib.imap0 (index: color: "${toString index}=${color}") theme.terminal;
in
{
  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;
    settings.theme = theme.name;
    themes.${theme.name} = {
      palette = terminalPalette;
      background = stripHash colors.background;
      foreground = stripHash colors.foreground;
      cursor-color = stripHash colors.accent;
      selection-background = stripHash colors.selection;
      selection-foreground = stripHash colors.foreground;
    };
  };

  programs.yazi.theme = {
    app.overall.bg = colors.background;
    mgr = {
      cwd = { fg = colors.accent; bold = true; };
      find_keyword = { fg = colors.warning; bold = true; };
      find_position = { fg = colors.foregroundSoft; };
      symlink_target = { fg = colors.accent; italic = true; };
      marker_copied = { fg = colors.success; bg = colors.success; };
      marker_cut = { fg = colors.error; bg = colors.error; };
      marker_marked = { fg = colors.warning; bg = colors.warning; };
      marker_selected = { fg = colors.accent; bg = colors.accent; };
      border_symbol = "│";
      border_style = { fg = colors.border; };
    };
    indicator = {
      parent = { fg = colors.muted; bg = colors.muted; };
      current = { fg = colors.accent; bg = colors.accent; };
      preview = { fg = colors.border; bg = colors.border; };
    };
    tabs = {
      active = { fg = colors.background; bg = colors.accent; bold = true; };
      inactive = { fg = colors.foregroundSoft; bg = colors.backgroundDark; };
    };
    mode = {
      normal_main = { fg = colors.background; bg = colors.accent; bold = true; };
      normal_alt = { fg = colors.accent; bg = colors.selection; };
      select_main = { fg = colors.background; bg = colors.warning; bold = true; };
      select_alt = { fg = colors.warning; bg = colors.selection; };
      unset_main = { fg = colors.background; bg = colors.error; bold = true; };
      unset_alt = { fg = colors.error; bg = colors.selection; };
    };
  };

  services.swaync = {
    settings = {
      positionX = "right";
      positionY = "bottom";
      control-center-positionX = "right";
      control-center-positionY = "none";
      layer = "overlay";
      control-center-layer = "overlay";
      cssPriority = "user";
      notification-icon-size = 48;
      notification-body-image-height = 100;
      notification-body-image-width = 200;
      timeout = 6;
      timeout-low = 4;
      timeout-critical = 0;
      fit-to-screen = false;
      control-center-width = 400;
      notification-window-width = 400;
      keyboard-shortcuts = true;
      image-visibility = "when-available";
      transition-time = 200;
      hide-on-clear = true;
      hide-on-action = true;
      widgets = [ "title" "dnd" "notifications" ];
      widget-config = {
        title = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "Clear";
        };
        dnd.text = "Do Not Disturb";
      };
    };

    style = ''
      * {
        color: ${colors.foreground};
      }

      .floating-notifications.right {
        margin-right: 2px;
      }

      .control-center {
        background: ${colors.background};
        border: 1px solid ${colors.accent};
        border-radius: 6px;
        margin: 8px;
        padding: 8px;
      }

      .control-center .notification-row {
        margin: 4px 0;
      }

      .notification-row {
        outline: none;
      }

      .notification {
        background: ${colors.background};
        border: 1px solid ${colors.backgroundDarker};
        border-radius: 6px;
        margin: 4px 2px 4px 8px;
        padding: 0;
      }

      .notification:hover {
        border-color: ${colors.accent};
      }

      .notification-content {
        padding: 8px 12px;
      }

      .close-button {
        background: ${colors.backgroundDark};
        color: ${colors.error};
        border: 1px solid ${colors.border};
        border-radius: 6px;
        padding: 2px 6px;
        margin: 8px;
      }

      .summary {
        color: ${colors.foreground};
        font-weight: bold;
      }

      .body {
        color: ${colors.foregroundSoft};
      }

      .time {
        color: ${colors.accent};
      }

      .notification.critical {
        border-color: ${colors.error};
      }

      .widget-title {
        color: ${colors.foreground};
        font-weight: bold;
        margin: 4px 8px;
      }

      .widget-title > button {
        background: ${colors.backgroundDark};
        color: ${colors.accent};
        border: 1px solid ${colors.border};
        border-radius: 6px;
        padding: 4px 12px;
      }

      .widget-dnd {
        color: ${colors.foreground};
        margin: 4px 8px;
      }

      .widget-dnd > switch {
        background: ${colors.selection};
        border: 1px solid ${colors.backgroundDarker};
        border-radius: 12px;
      }

      .widget-dnd > switch:checked {
        background: ${colors.accent};
      }

      .widget-dnd > switch slider {
        background: ${colors.foreground};
        border-radius: 50%;
      }
    '';
  };

  gtk = {
    enable = true;
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
