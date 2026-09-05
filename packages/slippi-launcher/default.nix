{
  appimageTools,
  curl,
  fetchurl,

  lib,
  libglvnd,
  libusb1,
  makeDesktopItem,
  symlinkJoin,
  udev,
}:
let
  pname = "slippi-launcher";
  version = "2.15.1";

  src = fetchurl {
    url = "https://github.com/project-slippi/slippi-launcher/releases/download/v${version}/Slippi-Launcher-${version}-x86_64.AppImage";
    hash = "sha256-sYKH+h8pVG8uo6Cg9mtGGrkp/fkwbBlOgc5BeZgAuxs=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };

  launcher = appimageTools.wrapType2 {
    inherit pname version src;
    extraPkgs = _pkgs: [
      curl

      libglvnd
      libusb1
      udev
    ];

    # The current Slippi Dolphin AppImages bundle a libcurl that lacks the
    # CURL_OPENSSL_4 symbol version required by their own executable. Prefer
    # nixpkgs' OpenSSL-flavoured libcurl for both launcher-managed Dolphins.
    profile = ''
      export LD_PRELOAD="${lib.getLib curl}/lib/libcurl.so.4''${LD_PRELOAD:+:$LD_PRELOAD}"
      export APPIMAGE_EXTRACT_AND_RUN=1
    '';
  };

  desktopItem = makeDesktopItem {
    name = pname;
    desktopName = "Slippi Launcher";
    comment = "Play Slippi Online and manage Melee replays";
    exec = "${launcher}/bin/${pname} --no-sandbox %U";
    icon = "slippi-launcher";
    categories = [ "Game" ];
    startupWMClass = "Slippi Launcher";
    mimeTypes = [ "x-scheme-handler/slippi" ];
  };
in
symlinkJoin {
  inherit pname version;
  paths = [
    launcher
    desktopItem
  ];

  postBuild = ''
    mkdir -p $out/share/icons
    cp -r ${appimageContents}/usr/share/icons/hicolor $out/share/icons/
  '';

  meta = {
    description = "Launcher for Slippi Online and Slippi replay tools";
    homepage = "https://slippi.gg";
    changelog = "https://github.com/project-slippi/slippi-launcher/releases/tag/v${version}";
    license = lib.licenses.gpl3Only;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = pname;
    platforms = [ "x86_64-linux" ];
  };
}
