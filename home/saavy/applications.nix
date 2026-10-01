{ pkgs, inputs, ... }:
let
  helium = pkgs.callPackage ../../packages/helium.nix { };
  chatgptApp = pkgs.callPackage ../../packages/chatgpt-app { };
  claudeDesktop = pkgs.callPackage ../../packages/claude-desktop { };
  # Official delta-nix flake package (fetchurl + patchelf of the stable
  # release) — replaces the retired local closed-beta tarball packaging.
  delta = inputs.delta.packages.${pkgs.stdenv.hostPlatform.system}.delta;
  # Zed editor from the official in-repo flake (crane source build on
  # upstream's own toolchain/nixpkgs pins). Tag-pinned in flake.nix: see
  # the comment there for why this input must not track a moving ref.
  zed = inputs.zed.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  home.packages = [
    helium
    chatgptApp
    delta
    claudeDesktop
    pkgs.discord
    pkgs.libnotify
    pkgs.hyprshot
    pkgs.gpu-screen-recorder
    pkgs.obs-studio
    pkgs.spotify
    pkgs.slurp
    # Zed official-flake source build replaces the nixpkgs binary here.
    zed
    pkgs.wl-clipboard
    # Image editors: Aseprite for pixel-level texture work (textures.gg's
    # external editor), GIMP for photo-style edits.
    pkgs.aseprite
    pkgs.gimp
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

  # Anthropic only publishes Debian packages for Linux, resolved from its apt
  # repository index at update time. Same shape as the ChatGPT app above: the
  # official payload lives outside the Nix store; claudeDesktop supplies the
  # stable FHS wrapper and desktop entry.
  systemd.user.services.claude-desktop-update = {
    Unit.Description = "Update the Anthropic Claude Desktop app";
    Service = {
      Type = "oneshot";
      ExecStart = "${claudeDesktop}/bin/claude-desktop-update";
    };
  };

  systemd.user.timers.claude-desktop-update = {
    Unit.Description = "Periodically update the Anthropic Claude Desktop app";
    Install.WantedBy = [ "timers.target" ];
    Timer = {
      OnBootSec = "2m";
      OnUnitActiveSec = "6h";
      Persistent = true;
      RandomizedDelaySec = "10m";
      Unit = "claude-desktop-update.service";
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
