{
  appimage-run,
  appimageTools,
  fetchurl,
  lib,
  makeDesktopItem,
  symlinkJoin,
  writeShellScriptBin,
}:
let
  pname = "ssbm-nucleus";
  version = "0.8.10";

  # The hash is the SHA-256 GitHub publishes for this release asset.
  src = fetchurl {
    url = "https://github.com/ssbmNucleus/ssbmNucleus/releases/download/v${version}/SSBM-Nucleus_${version}_x86_64.AppImage";
    hash = "sha256-yuVznaLIYgDUxjyivU28kZPBCMWGpSixlwMaqJuG1no=";
  };

  # Run the AppImage with appimage-run, which unpacks it under ~/.cache with
  # its own file modes. Unpacked into the read-only Nix store instead, setup
  # copies read-only assets into ~/.melee-nexus and then fails with
  # "Permission denied" when it writes them again. The bundled .NET tools
  # (mexcli) also load ICU and its companions at run time.
  runner = appimage-run.override {
    extraPkgs = pkgs: [
      pkgs.icu
      pkgs.krb5
      pkgs.openssl
      pkgs.zlib
    ];
  };

  app = writeShellScriptBin pname ''
    exec ${runner}/bin/appimage-run ${src} "$@"
  '';

  appimageContents = appimageTools.extract { inherit pname version src; };

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "SSBM Nucleus";
    comment = "Browse, create and install Super Smash Bros. Melee skins";
    exec = "${app}/bin/${pname} %U";
    icon = pname;
    categories = [ "Game" ];
  };
in
symlinkJoin {
  inherit pname version;
  paths = [
    app
    desktopItem
  ];

  # Use the AppImage's own icon under our desktop entry's name, if it ships
  # one.
  postBuild = ''
    icon=$(find ${appimageContents} -maxdepth 1 -name '*.png' | head -n 1)
    if [ -n "$icon" ]; then
      mkdir -p $out/share/icons/hicolor/512x512/apps
      cp "$icon" $out/share/icons/hicolor/512x512/apps/${pname}.png
    fi
  '';

  meta = {
    description = "Melee skin browser, creator and installer";
    homepage = "https://ssbmnucleus.net";
    changelog = "https://github.com/ssbmNucleus/ssbmNucleus/releases/tag/v${version}";
    # The releases repository publishes no license.
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
  };
}
