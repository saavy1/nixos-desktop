{ theme, ... }:
let
  controlCenterTop = theme.geometry.outerMargin + theme.shell.bar.height + theme.geometry.shellGap;
in
{
  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "bottom";
      control-center-positionX = "right";
      control-center-positionY = "top";
      control-center-margin-top = controlCenterTop;
      control-center-margin-right = theme.geometry.outerMargin;
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
      widgets = [
        "title"
        "dnd"
        "notifications"
      ];
      widget-config = {
        title = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "Clear";
        };
        dnd.text = "Do Not Disturb";
      };
    };
  };
}
