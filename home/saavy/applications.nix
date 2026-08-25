{ pkgs, ... }:
let
  helium = pkgs.callPackage ../../packages/helium.nix { };

  clipboardPicker = pkgs.writeShellApplication {
    name = "clipboard-picker";
    runtimeInputs = [
      pkgs.cliphist
      pkgs.hyprlauncher
      pkgs.wl-clipboard
    ];
    text = ''
      selection="$(cliphist list | hyprlauncher --dmenu)" || exit 0
      [[ -n "$selection" ]] || exit 0
      printf '%s' "$selection" | cliphist decode | wl-copy
    '';
  };
in
{
  home.packages = [
    clipboardPicker
    helium
    pkgs.hyprlauncher
    pkgs.libnotify
    pkgs.hyprshot
    pkgs.wl-clipboard
  ];

  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.yazi.enable = true;

  services.cliphist = {
    enable = true;
    systemdTargets = [ "graphical-session.target" ];
  };

  systemd.user.services.hyprlauncher = {
    Unit = {
      Description = "Hyprlauncher daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = "${pkgs.hyprlauncher}/bin/hyprlauncher --daemon";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/pdf" = [ "helium.desktop" ];
      "text/html" = [ "helium.desktop" ];
      "x-scheme-handler/http" = [ "helium.desktop" ];
      "x-scheme-handler/https" = [ "helium.desktop" ];
    };
  };
}
