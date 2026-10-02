{
  config,
  inputs,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  cfg = config.saavy.cua;
  lua = lib.generators.mkLuaInline;

  # Only the bootstrap: used until the updater below has built upstream main
  # once, and whenever that build is missing.
  lockedDriver = inputs.cua.packages.${pkgs.stdenv.hostPlatform.system}.cua-driver;

  # Shared by every script here; Hermes' service has no XDG_STATE_HOME.
  stateDir = ''"''${XDG_STATE_HOME:-$HOME/.local/state}/cua"'';

  # The `cua-driver` every agent launches. It runs the newest upstream build,
  # refuses to drive the desktop while Cua is switched off, and supplies what
  # upstream's package leaves to the host: `wtype` (the driver shells out to it
  # to type on wlroots compositors; without it typing falls through to a libei
  # portal Hyprland does not have) and the native Wayland backend.
  cuaDriver = pkgs.writeShellApplication {
    name = "cua-driver";
    runtimeInputs = [ pkgs.wtype ];
    text = ''
      state=${stateDir}
      driver=${lockedDriver}/bin/cua-driver
      if [[ -x "$state/latest/bin/cua-driver" ]]; then
        driver="$state/latest/bin/cua-driver"
      fi

      case "''${1:-}" in
        mcp | serve | call)
          if [[ ! -e "$state/enabled" ]]; then
            echo "cua-driver: desktop control is off; run 'cua on' to enable it" >&2
            exit 1
          fi
          ;;
      esac

      export CUA_DRIVER_RS_ENABLE_WAYLAND="''${CUA_DRIVER_RS_ENABLE_WAYLAND:-1}"
      exec "$driver" "$@"
    '';
  };

  # Upstream ships several releases a week, so the driver follows main instead
  # of flake.lock. A failed build leaves the previous link in place.
  cuaDriverUpdate = pkgs.writeShellApplication {
    name = "cua-driver-update";
    runtimeInputs = [ osConfig.nix.package ];
    text = ''
      state=${stateDir}
      mkdir -p "$state"
      nix build --refresh --cores 8 "github:trycua/cua#cua-driver" --out-link "$state/latest"
    '';
  };

  cuaControl = pkgs.writeShellApplication {
    name = "cua";
    runtimeInputs = [
      cuaDriver
      pkgs.coreutils
      pkgs.libnotify
      pkgs.procps
      pkgs.systemd
    ];
    text = ''
      state=${stateDir}
      mkdir -p "$state"

      is_on() { [[ -e "$state/enabled" ]]; }
      announce() {
        echo "cua: $1"
        notify-send --app-name Cua --expire-time 3000 "Cua" "$1" 2>/dev/null || true
      }

      turn_on() {
        touch "$state/enabled"
        announce "desktop control on"
      }

      # Off must hold immediately: revoke live sessions, then stop every driver
      # so an action already in flight cannot finish.
      turn_off() {
        rm -f "$state/enabled"
        timeout 3 cua-driver revoke --all >/dev/null 2>&1 || true
        pkill -x cua-driver || true
        announce "desktop control off"
      }

      case "''${1:-status}" in
        on) turn_on ;;
        off) turn_off ;;
        toggle) if is_on; then turn_off; else turn_on; fi ;;
        status)
          if is_on; then echo "control: on"; else echo "control: off"; fi
          echo "driver:  $(cua-driver --version)"
          if [[ -x "$state/latest/bin/cua-driver" ]]; then
            echo "source:  upstream main ($(readlink -f "$state/latest"))"
          else
            echo "source:  flake.lock fallback (run 'cua update')"
          fi
          echo "running: $(pgrep -xc cua-driver || true)"
          ;;
        update)
          systemctl --user start cua-driver-update.service
          echo "driver: $(cua-driver --version)"
          ;;
        *)
          echo "usage: cua [on|off|toggle|status|update]" >&2
          exit 2
          ;;
      esac
    '';
  };

  # Built against the exact compositor NixOS runs; the plugin refuses to load
  # on any Hyprland ABI mismatch, so a Hyprland bump rebuilds it in lockstep.
  cuaHyprlandPlugin = pkgs.callPackage ../../packages/cua-hyprland-plugin {
    hyprland = osConfig.programs.hyprland.package;
    cuaSrc = inputs.cua;
  };
in
{
  options.saavy.cua = {
    package = lib.mkOption {
      type = lib.types.package;
      default = cuaDriver;
      readOnly = true;
      description = "The gated, self-updating cua-driver wrapper agents should launch.";
    };

    hyprland = lib.mkEnableOption ''
      the Cua Driver Hyprland plugin with isolated agent seats (Cua-Agent,
      Cua-Agent-2). Off by default because gpui apps (Zed, custom gpui apps)
      bind the last advertised wl_seat and then never receive the human's
      pointer. The plugin keeps its seats until Hyprland restarts, so toggling
      this needs a fresh session. It is built from flake.lock while the driver
      follows upstream main, so run `nix flake update cua` before enabling it'';
  };

  config = lib.mkMerge [
    {
      home.packages = [
        cuaDriver
        cuaControl
      ];

      home.file.".claude/skills/cua-desktop/SKILL.md".source = ./skills/cua-desktop/SKILL.md;
      home.file.".agents/skills/cua-desktop/SKILL.md".source = ./skills/cua-desktop/SKILL.md;

      # Without the plugin the driver acts through the one real pointer and
      # keyboard, so the switch has to be reachable while an agent holds them.
      wayland.windowManager.hyprland.settings.bind = [
        {
          _args = [
            "SUPER + CTRL + ALT + C"
            (lua "hl.dsp.exec_cmd(\"${cuaControl}/bin/cua toggle\")")
            { description = "Agents · Toggle Cua desktop control"; }
          ];
        }
      ];

      systemd.user.services.cua-driver-update = {
        Unit.Description = "Build the latest upstream cua-driver";
        Service = {
          Type = "oneshot";
          ExecStart = "${cuaDriverUpdate}/bin/cua-driver-update";
        };
      };

      systemd.user.timers.cua-driver-update = {
        Unit.Description = "Build the latest upstream cua-driver";
        Timer = {
          OnStartupSec = "5min";
          OnUnitActiveSec = "12h";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    }

    (lib.mkIf cfg.hyprland {
      wayland.windowManager.hyprland = {
        plugins = [ "${cuaHyprlandPlugin}/lib/cua/hyprland/cua-hyprland-plugin.so" ];
        settings.config.plugin.cua.enabled = true;
      };
    })
  ];
}
