{ inputs, pkgs, ... }:
let
  herdrPackage = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
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


}
