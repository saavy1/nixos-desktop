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

  # Built against the exact compositor NixOS runs; the plugin refuses to load
  # on any Hyprland ABI mismatch, so a Hyprland bump rebuilds it in lockstep.
  cuaHyprlandPlugin = pkgs.callPackage ../../packages/cua-hyprland-plugin {
    hyprland = osConfig.programs.hyprland.package;
    cuaSrc = inputs.cua;
  };
in
{
  options.saavy.cua.hyprland = lib.mkEnableOption ''
    the Cua Driver Hyprland integration: the compositor plugin with isolated
    agent seats (Cua-Agent, Cua-Agent-2) and the driver's native Wayland
    backend. Off by default because gpui apps (Zed, custom gpui apps) bind the
    last advertised wl_seat and then never receive the human's pointer. The
    plugin keeps its seats until Hyprland restarts, so toggling this needs a
    fresh session'';

  config = lib.mkIf cfg.hyprland {
    wayland.windowManager.hyprland = {
      plugins = [ "${cuaHyprlandPlugin}/lib/cua/hyprland/cua-hyprland-plugin.so" ];
      settings.config.plugin.cua.enabled = true;
    };

    # Every cua-driver MCP (Claude, Codex, OMP, Hermes, ...) uses the native
    # Wayland backend: layer-shell agent cursor overlay and the plugin's agent
    # seats. Without it the driver falls back to XWayland/X11 input.
    home.sessionVariables.CUA_DRIVER_RS_ENABLE_WAYLAND = "1";
    systemd.user.sessionVariables.CUA_DRIVER_RS_ENABLE_WAYLAND = "1";
    services.hermes-agent.environment.CUA_DRIVER_RS_ENABLE_WAYLAND = "1";
  };
}
