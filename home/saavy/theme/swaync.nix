{ theme, ... }:
let
  inherit (theme) colors;
in
{
  services.swaync.style = ''
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
}
