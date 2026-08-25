{ inputs, pkgs, ... }:
{
  imports = [
    inputs.hermes-agent.homeManagerModules.default
    inputs.omp.homeManagerModules.default
  ];

  home.packages = [
    pkgs.codex
    pkgs.pi-coding-agent
  ];

  programs.omp = {
    enable = true;
    settings.startup.quiet = true;
    settings.setupVersion = 1;
  };

  programs.hermes-agent = {
    enable = true;
    desktop = {
      enable = true;
      package = inputs.hermes-desktop.packages.${pkgs.stdenv.hostPlatform.system}.default.hermesDesktop;
    };
  };

  services.hermes-agent = {
    enable = true;
    settings.model.default = "anthropic/claude-sonnet-4";
  };
}
