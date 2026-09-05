# Oh My Pi packaged directly from its official release binary.
#
# OMP publishes many releases per day; pinning the release here decouples the
# installed CLI from the source flake's package and lock/update cadence.
{
  fetchurl,
  lib,
  stdenvNoCC,
}:
let
  pin = import ./source-pin.nix;
  source =
    pin.sources.${stdenvNoCC.hostPlatform.system}
      or (throw "OMP is not pinned for ${stdenvNoCC.hostPlatform.system}");
  releaseBase = "https://github.com/can1357/oh-my-pi/releases/download/v${pin.version}";
  licenseFile = fetchurl {
    url = "${releaseBase}/LICENSE";
    hash = pin.licenseHash;
  };
  noticesFile = fetchurl {
    url = "${releaseBase}/THIRD-PARTY-NOTICES.txt";
    hash = pin.noticesHash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "omp";
  inherit (pin) version;

  src = fetchurl {
    url = "${releaseBase}/${source.asset}";
    inherit (source) hash;
  };

  dontUnpack = true;
  # Bun's single-file executable locates embedded native addons by file offset.
  # Patching its interpreter or RPATH corrupts extraction. The official glibc
  # binary therefore stays untouched and runs through the host's nix-ld setup
  # (enabled in modules/common/development.nix).
  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/omp"

    install -Dm644 "${licenseFile}" "$out/share/doc/omp/LICENSE"
    install -Dm644 "${noticesFile}" "$out/share/doc/omp/THIRD-PARTY-NOTICES.txt"

    runHook postInstall
  '';

  # Prove the generic fixup phase preserved the release executable exactly.
  # Runtime checks happen against this output after the NixOS build, where the
  # configured nix-ld interpreter is available (unlike in the build sandbox).
  postFixup = ''
    cmp "$src" "$out/bin/omp"
  '';

  meta = {
    description = "Terminal-based coding agent with multi-model support";
    homepage = "https://omp.sh";
    changelog = "https://github.com/can1357/oh-my-pi/releases/tag/v${pin.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "omp";
    platforms = builtins.attrNames pin.sources;
  };
}
