{ pkgs, ... }:
let
  helium = pkgs.callPackage ../../packages/helium.nix { };
in
{
  home.packages = [
    helium
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
