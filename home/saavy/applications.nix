{ pkgs, inputs, ... }:
let
  helium = pkgs.callPackage ../../packages/helium.nix { };
  chatgptApp = pkgs.callPackage ../../packages/chatgpt-app { };
  delta = pkgs.callPackage ../../packages/delta {
    inherit (inputs) delta-tarball;
    version = (import ../../packages/delta/source-pin.nix).version;
  };
in
{
  home.packages = [
    helium
    chatgptApp
    delta
    pkgs.discord
    pkgs.libnotify
    pkgs.hyprshot
    pkgs.gpu-screen-recorder
    pkgs.spotify
    pkgs.slurp
    pkgs.zed-editor
    pkgs.wl-clipboard
  ];

  programs.ghostty = {
    enable = true;
    enableFishIntegration = true;
  };
  programs.mpv = {
    enable = true;
    config = {
      vo = "gpu-next";
      gpu-api = "vulkan";
      gpu-context = "waylandvk";
      hwdec = "auto-safe";
      target-colorspace-hint = "yes";
      target-colorspace-hint-mode = "source";
    };
  };

  programs.yazi.enable = true;

  # OpenAI only publishes mutable Debian/RPM packages for Linux. Keep the
  # official payload outside the Nix store and refresh its `latest` channel in
  # place; chatgptApp supplies the stable FHS wrapper and desktop entry.
  systemd.user.services.chatgpt-update = {
    Unit.Description = "Update the OpenAI ChatGPT/Codex desktop app";
    Service = {
      Type = "oneshot";
      ExecStart = "${chatgptApp}/bin/chatgpt-update";
    };
  };

  systemd.user.timers.chatgpt-update = {
    Unit.Description = "Periodically update the OpenAI ChatGPT/Codex desktop app";
    Install.WantedBy = [ "timers.target" ];
    Timer = {
      OnBootSec = "2m";
      OnUnitActiveSec = "6h";
      Persistent = true;
      RandomizedDelaySec = "10m";
      Unit = "chatgpt-update.service";
    };
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
