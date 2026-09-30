{ inputs, pkgs, config, lib, ... }:
let
  herdrPackage = inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default;
  cuaDriverPackage = inputs.cua.packages.${pkgs.stdenv.hostPlatform.system}.cua-driver;
  codex = pkgs.callPackage ../../packages/codex { };
  omp = pkgs.callPackage ../../packages/omp { };
  droid = pkgs.callPackage ../../packages/droid { };
  polylane = pkgs.callPackage ../../packages/polylane { };
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
    codex
    pkgs.pi-coding-agent
    droid
    polylane
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

  # The upstream module manages Home Manager integration, while the package is
  # pinned directly from OMP's official release in packages/omp. OMP itself
  # owns ~/.omp/agent/config.yml; declaring programs.omp.settings would replace
  # runtime changes on every switch and force re-onboarding.
  programs.omp = {
    enable = true;
    package = omp;
  };

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

  # Expose the dashboard backend to authenticated Hermes Desktop clients on
  # the tailnet. Credentials stay in the existing owner-only environment file.
  systemd.user.services.hermes-dashboard = {
    Unit = {
      Description = "Hermes Dashboard Gateway";
      After = [
        "network-online.target"
        "hermes-agent.service"
      ];
      Wants = [ "network-online.target" ];
    };
    Install.WantedBy = [ "default.target" ];
    Service = {
      Type = "simple";
      WorkingDirectory = "/home/saavy";
      Environment = [
        "HERMES_HOME=/home/saavy/.hermes"
        "PATH=${config.programs.hermes-agent.package}/bin:${pkgs.coreutils}/bin"
      ];
      EnvironmentFile = "/home/saavy/.config/hermes/environment";
      ExecStart = "${config.programs.hermes-agent.package}/bin/hermes dashboard --host 0.0.0.0 --port 9119 --no-open --skip-build";
      Restart = "always";
      RestartSec = 5;
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
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
