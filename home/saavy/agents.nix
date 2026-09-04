{ inputs, pkgs, config, lib, ... }:
let
  herdrPackage = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
  cuaDriverPackage = inputs.cua.packages.${pkgs.stdenv.hostPlatform.system}.cua-driver;
  droid = pkgs.callPackage ../../packages/droid { };
  agentOrchestratorPackage = pkgs.callPackage ../../packages/agent-orchestrator { };
  moshiHook = pkgs.callPackage ../../packages/moshi-hook.nix { };
  enableMoshiHermesPlugin = pkgs.writeScript "enable-moshi-hermes-plugin" ''
    #!${pkgs.python3.withPackages (ps: [ ps.pyyaml ])}/bin/python3
    import os
    import sys
    from pathlib import Path

    import yaml
    class IndentedSafeDumper(yaml.SafeDumper):
        def increase_indent(self, flow=False, indentless=False):
            return super().increase_indent(flow, indentless=False)


    config_path = Path(sys.argv[1])
    with config_path.open() as config_file:
        hermes_config = yaml.safe_load(config_file) or {}

    enabled = hermes_config.setdefault("plugins", {}).setdefault("enabled", [])
    if not isinstance(enabled, list):
        raise TypeError("Hermes plugins.enabled must be a list")
    if "moshi-hooks" not in enabled:
        enabled.append("moshi-hooks")

    temporary_path = config_path.with_suffix(".yaml.moshi")
    with temporary_path.open("w") as config_file:
        yaml.dump(hermes_config, config_file, Dumper=IndentedSafeDumper, sort_keys=False)
    os.chmod(temporary_path, 0o600)
    os.replace(temporary_path, config_path)
  '';
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
  home.file.".local/bin/moshi-hook".source = "${moshiHook}/bin/moshi-hook";
  home.file.".local/bin/moshi".source = "${moshiHook}/bin/moshi";
  home.file.".hermes/plugins/moshi-hooks".source = "${moshiHook}/share/hermes/moshi-hooks";

  # Agent modules can rewrite their runtime configuration during activation.
  # Refresh their hooks afterward; Hermes uses a declarative plugin because
  # Moshi's installer emits YAML incompatible with Hermes' Nix merge format.
  home.activation.installMoshiHooks = lib.hm.dag.entryAfter [ "linkGeneration" "hermesAgentSetup" ] ''
    $DRY_RUN_CMD ${moshiHook}/bin/moshi-hook install \
      --target codex,omp,pi
    $DRY_RUN_CMD ${enableMoshiHermesPlugin} ${config.services.hermes-agent.hermesHome}/config.yaml
  '';

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

  # Pairing and hook configuration are runtime state managed by moshi-hook;
  # Home Manager owns the executable and keeps its bridge daemon available.
  systemd.user.services.moshi-hook = {
    Unit.Description = "Moshi agent hook bridge";
    Install.WantedBy = [ "default.target" ];
    Service = {
      ExecStart = "${moshiHook}/bin/moshi-hook serve";
      Restart = "always";
      RestartSec = 5;
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
  };
}
