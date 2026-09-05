{
  autoPatchelfHook,
  copyDesktopItems,
  dbus,
  fetchurl,
  fontconfig,
  freetype,
  glib,
  gtk3,
  icu,
  krb5,
  lib,
  libGL,
  libICE,
  libSM,
  libX11,
  libXcursor,
  libXext,
  libXi,
  libXrandr,
  libxkbcommon,
  makeDesktopItem,
  makeWrapper,
  openssl,
  stdenv,
  unzip,
  vulkan-loader,
}:
let
  version = "2.1.0";

  cliSrc = fetchurl {
    url = "https://github.com/Nanook/NKit/releases/download/v${version}/NKit_CLI_linux-x64_${version}.zip";
    hash = "sha256-+wNXBNkAVqMo682p7WA/zjLfzbMElQgC8kghz+0WiLw=";
  };

  uiSrc = fetchurl {
    url = "https://github.com/Nanook/NKit/releases/download/v${version}/NKit_UI_linux-x64_${version}.zip";
    hash = "sha256-VAkSn9bzWjqgsDoia5VVuGTCBwvbcHi0m2JeJB0ldAw=";
  };

  runtimeLibraries = [
    dbus
    fontconfig
    freetype
    glib
    gtk3
    icu
    krb5
    libGL
    libICE
    libSM
    libX11
    libXcursor
    libXext
    libXi
    libXrandr
    libxkbcommon
    openssl
    stdenv.cc.cc.lib
    vulkan-loader
  ];
in
stdenv.mkDerivation {
  pname = "nkit";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
    makeWrapper
    unzip
  ];

  buildInputs = runtimeLibraries;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/nkit/{cli,ui} $out/bin
    unzip -q ${cliSrc} -d $out/libexec/nkit/cli
    unzip -q ${uiSrc} -d $out/libexec/nkit/ui

    # The release ZIPs default to portable mode, which would try to write
    # configuration beside the executables in the immutable Nix store. Without
    # these files NKit intentionally uses ~/.config/nkit and seeds its defaults
    # there on first run.
    rm $out/libexec/nkit/cli/nkit.yaml $out/libexec/nkit/ui/nkit-ui.yaml
    chmod +x $out/libexec/nkit/{cli/{nkit,nkds},ui/{nkit-ui,nkds-ui}}

    for program in nkit nkds; do
      makeWrapper "$out/libexec/nkit/cli/$program" "$out/bin/$program" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibraries}"
    done
    for program in nkit-ui nkds-ui; do
      makeWrapper "$out/libexec/nkit/ui/$program" "$out/bin/$program" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibraries}"
    done

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "nkit-ui";
      desktopName = "NKit";
      comment = "Convert, expand, verify, and repair disc images";
      exec = "nkit-ui";
      icon = "application-x-cd-image";
      categories = [ "Utility" ];
      terminal = false;
    })
  ];

  meta = {
    description = "Multipurpose game disc image processor";
    homepage = "https://github.com/Nanook/NKit";
    changelog = "https://github.com/Nanook/NKit/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "nkit";
    platforms = [ "x86_64-linux" ];
  };
}
