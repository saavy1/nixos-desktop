{ inputs, pkgs, config, ... }:
let
  herdrPackage = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
  cuaDriverPackage = inputs.cua.packages.${pkgs.stdenv.hostPlatform.system}.cua-driver;
  droid = pkgs.callPackage ../../packages/droid { };
  agentOrchestratorPackage = pkgs.callPackage ../../packages/agent-orchestrator { };
in
{
  imports = [
    inputs.hermes-agent.homeManagerModules.default
    inputs.omp.homeManagerModules.default
  ];

  home.packages = [
    herdrPackage
    pkgs.pi-coding-agent
    droid
    agentOrchestratorPackage
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

  # OMP only: the package is installed here, but ~/.omp/agent/config.yml is
  # owned by omp itself. Declaring programs.omp.settings would re-install the
  # declared YAML over omp's runtime config on every home-manager switch
  # (resetting setupVersion and /settings changes), forcing re-onboarding.
  programs.omp.enable = true;

  # Single upstream input: module defaults wire CLI, services and desktop
  # from one build (programs.hermes-agent.desktop.package falls back to
  # package.hermesDesktop). Update via `nix flake update hermes-agent`.
  programs.hermes-agent = {
    enable = true;
    desktop.enable = true;
  };

  # Keep the local Hermes messaging gateway available across logout/reboot.
  # The Desktop application starts its own local backend when launched.
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

  };

  # Profile-scoped gateway for the infra profile. Cron jobs and the kanban
  # dispatcher run inside the profile's own gateway (the scheduler ticker is
  # per-profile by design), so scheduled infra jobs (e.g. fleet-health-daily)
  # and infra kanban dispatch need their own durable gateway. Linger is
  # enabled for saavy, so this unit survives logout and reboot.
  systemd.user.services."hermes-gateway-infra" = {
    Unit = {
      Description = "Hermes Agent Gateway (infra profile)";
      After = [ "default.target" ];
    };
    Install.WantedBy = [ "default.target" ];
    Service = {
      Type = "simple";
      WorkingDirectory = "/home/saavy";
      Environment = [
        "PATH=${config.programs.hermes-agent.package}/bin:${pkgs.coreutils}/bin:${pkgs.bash}/bin"
      ];
      ExecStart = "${config.programs.hermes-agent.package}/bin/hermes --profile infra gateway";
      Restart = "always";
      RestartSec = 5;
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
  };
}
