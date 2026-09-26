{
  lib,
  hyprlandPlugins,
  hyprland,
  cmake,
  ninja,
  binutils,
  cuaSrc,
}:
# Cua Driver's Hyprland plugin with the v3 input candidate: two extra
# compositor seats (Cua-Agent, Cua-Agent-2) so agents get their own cursor and
# keyboard instead of sharing the human's. The module is ABI-pinned, so it is
# built against the same `hyprland` derivation that programs.hyprland runs;
# `CUA_HYPRLAND_EXPECTED_VERSION` refuses any other header version.
hyprlandPlugins.mkHyprlandPlugin {
  pluginName = "cua-hyprland-plugin";
  version = "0.1.0-${builtins.substring 0 7 (cuaSrc.rev or "dirty")}";
  inherit hyprland;

  src = "${cuaSrc}/libs/cua-driver/hyprland-plugin";

  nativeBuildInputs = [
    cmake
    ninja
    binutils
  ];

  cmakeFlags = [
    (lib.cmakeBool "CUA_HYPRLAND_INPUT" true)
    (lib.cmakeBool "BUILD_TESTING" false)
    (lib.cmakeFeature "CUA_HYPRLAND_EXPECTED_VERSION" hyprland.version)
  ];

  meta = {
    description = "Cua Driver Hyprland plugin with isolated agent input seats";
    homepage = "https://github.com/trycua/cua/tree/main/libs/cua-driver/hyprland-plugin";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
