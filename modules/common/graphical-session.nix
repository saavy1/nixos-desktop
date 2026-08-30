{ lib, pkgs, ... }:
let
  sessionCommand = "${lib.getExe pkgs.uwsm} start hyprland.desktop";
in
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  programs.hyprlock.enable = true;

  # Secret Service (org.freedesktop.secrets) provider. Apps such as Delta use
  # it as their OS keychain for OAuth tokens; without it credential writes
  # fail with "DBus error … The name is not activatable".
  services.gnome.gnome-keyring.enable = true;
  # Unlock the login keyring when greetd signs the user in.
  security.pam.services.greetd.enableGnomeKeyring = true;

  fonts.packages = [
    pkgs.inter
    pkgs.jetbrains-mono
  ];

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
