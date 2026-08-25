{ lib, pkgs, ... }:
let
  sessionCommand = "${lib.getExe pkgs.uwsm} start hyprland.desktop";
in
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings = {
      initial_session = {
        command = sessionCommand;
        user = "saavy";
      };
      default_session.command = "${lib.getExe pkgs.tuigreet} --time --remember --cmd '${sessionCommand}'";
    };
  };

  systemd.user.services.hyprpolkitagent = {
    description = "Hyprland PolicyKit authentication agent";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    unitConfig.ConditionEnvironment = "WAYLAND_DISPLAY";
    serviceConfig = {
      ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
      Restart = "on-failure";
      TimeoutStopSec = 5;
    };
  };
}
