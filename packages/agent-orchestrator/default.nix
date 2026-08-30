# Agent Orchestrator (AO) — desktop IDE for managing fleets of coding agents,
# from https://github.com/Untrivial-ai/agent-orchestrator.
#
# Upstream's flake.nix is a development shell only (Go toolchain for their
# backend); they distribute no Nix packages. The supported Linux artifact is
# an Electron AppImage on GitHub Releases, so we pin the release by SRI hash
# and wrap it with appimageTools (FHS env) rather than building from source.
# wrapType2 is buildFHSEnv-based, so the desktop entry/icon are layered on
# with symlinkJoin instead of an install hook.
#
# Update: bump `version`, then refresh the hash with
#   nix-prefetch-url <release-url>; nix hash to-sri --type sha256 <hash>
{
  lib,
  appimageTools,
  fetchurl,
  symlinkJoin,
  makeDesktopItem,
}:
let
  version = "0.12.9";
  pname = "agent-orchestrator";

  src = fetchurl {
    url = "https://github.com/Untrivial-ai/agent-orchestrator/releases/download/v${version}/agent-orchestrator-linux-x64.AppImage";
    hash = "sha256-aiWO9/CB2vzY4moTVteqw8N2PKmaRT42QHh8k4ti6L8=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };

  # Electron bundles most of what it needs in the AppImage; these are the
  # common host libs its embedded runtime dlopens from FHS paths.
  ao = appimageTools.wrapType2 {
    inherit pname version src;
    extraPkgs =
      pkgs: with pkgs; [
        libuuid
        libgcrypt
        libgbm
      ];
  };

  desktopItem = makeDesktopItem {
    name = "agent-orchestrator";
    desktopName = "Agent Orchestrator";
    comment = "Manage fleets of coding agents from one place";
    exec = "${ao}/bin/agent-orchestrator --no-sandbox %U";
    icon = "${appimageContents}/agent-orchestrator.png";
    categories = [ "Development" ];
    startupWMClass = "Agent Orchestrator";
    mimeTypes = [ "x-scheme-handler/ao-app" ];
  };
in
symlinkJoin {
  inherit pname version;
  paths = [
    ao
    desktopItem
  ];

  meta = {
    description = "Desktop IDE for managing fleets of coding agents";
    homepage = "https://github.com/Untrivial-ai/agent-orchestrator";
    changelog = "https://github.com/Untrivial-ai/agent-orchestrator/releases";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "agent-orchestrator";
    platforms = [ "x86_64-linux" ];
  };
}
