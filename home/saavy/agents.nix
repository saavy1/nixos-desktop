{ inputs, pkgs, ... }:
let
  herdrPackage = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
  cuaDriverPackage = inputs.cua.packages.${pkgs.stdenv.hostPlatform.system}.cua-driver;
in
{
  imports = [
    inputs.hermes-agent.homeManagerModules.default
    inputs.omp.homeManagerModules.default
  ];

  home.packages = [
    herdrPackage
    pkgs.codex
    pkgs.pi-coding-agent
  ];

  # Hermes creates per-profile wrapper commands (for example `dev chat`) here.
  home.sessionPath = [ "$HOME/.local/bin" ];

  home.file.".agents/skills/herdr/SKILL.md".source = "${inputs.herdr}/skills/herdr/SKILL.md";

  xdg.desktopEntries.herdr = {
    name = "Herdr";
    genericName = "Agent runtime";
    comment = "Persistent terminal workspaces for coding agents";
    exec = "ghostty --working-directory=/home/saavy/dev -e ${herdrPackage}/bin/herdr";
    icon = "utilities-terminal";
    terminal = false;
    categories = [
      "Development"
      "System"
    ];
  };

  programs.omp = {
    enable = true;
    settings.startup.quiet = true;
    settings.setupVersion = 1;
  };

  # Single upstream input: module defaults wire CLI, services and desktop
  # from one build (programs.hermes-agent.desktop.package falls back to
  # package.hermesDesktop). Update via `nix flake update hermes-agent`.
  programs.hermes-agent = {
    enable = true;
    desktop.enable = true;
  };

  # Keep Hermes available across logout/reboot and restart both long-running
  # processes if they fail.  The NixOS user account enables linger.
  services.hermes-agent = {
    enable = true;
    gateway.enable = true;
    workingDirectory = "/home/saavy";
    environmentFiles = [ "/home/saavy/.config/hermes/environment" ];
    environment.CUA_DRIVER_RS_ENABLE_WAYLAND = "1";
    extraPackages = [
      cuaDriverPackage
      pkgs.at-spi2-core
      pkgs.glib
    ];
    restart = "always";
    restartSec = 5;

    settings.toolsets = [
      "hermes-cli"
      "computer_use"
    ];

    # One machine-level dashboard serves every Hermes profile. Basic auth is
    # loaded from the private environment file above; the separate token lets
    # Hermes Desktop attach to this backend instead of spawning another one.
    backend = {
      mode = "dashboard";
      host = "0.0.0.0";
      port = 9119;
      sessionTokenFile = "/home/saavy/.config/hermes/dashboard-session-token";
    };
  };
}
