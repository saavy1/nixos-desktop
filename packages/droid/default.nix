# Factory Droid CLI — terminal AI coding agent from https://factory.ai.
#
# Upstream distributes this as a single self-contained binary served from
# https://downloads.factory.ai/factory-cli/releases/<version>/linux/<arch>/droid.
# The official installer script (curl -fsSL https://app.factory.ai/cli | sh)
# currently pins version 0.209.1; keep `version` and the SRI `sha256` in sync
# with the published release. The hash below was taken from the release's own
# `droid.sha256` sidecar and verified against a fresh download.
#
# AVX2 note: the x64 build presumes AVX2 (the upstream installer probes
# /proc/cpuinfo and falls back to `x64-baseline` otherwise). This desktop's CPU
# reports avx2, so the plain x64 variant is pinned. Switch the URL segment to
# linux/x64-baseline before using this on an older machine.
#
# ELF: the binary requests /lib64/ld-linux-x86-64.so.2 and only links glibc
# basics (libc, pthread, dl, m) — no X11/GUI dependencies. The interpreter is
# rewritten to the stdenv glibc loader so the package does not depend on the
# machine's FHS compatibility symlink. Source check: this desktop has nix-ld
# at /lib64, so the unpatched binary also runs there; patching keeps the store
# path standalone.
{
  lib,
  stdenv,
  fetchurl,
  patchelf,
}:
let
  version = "0.209.1";
in
stdenv.mkDerivation {
  pname = "droid";
  inherit version;

  src = fetchurl {
    url = "https://downloads.factory.ai/factory-cli/releases/${version}/linux/x64/droid";
    hash = "sha256-lJZvH2PLYOrmvJN0nd9jmtJGNe0kLpwnueO1b5GFSMI=";
  };

  nativeBuildInputs = [ patchelf ];

  # A single prebuilt ELF, not an archive: install it verbatim.
  dontUnpack = true;
  dontStrip = true;

  installPhase = ''
    install -Dm755 "$src" "$out/bin/droid"
  '';

  postFixup = ''
    patchelf --set-interpreter "$(cat "$NIX_CC"/nix-support/dynamic-linker)" \
      "$out/bin/droid"
  '';

  # Prove the produced binary actually executes in the build sandbox.
  doInstallCheck = true;
  installCheckPhase = ''
    reported="$("$out/bin/droid" --version)"
    echo "installed droid reports: $reported"
    case "$reported" in
      ${version}) ;;
      *) echo "version mismatch: pinned ${version}, binary reports '$reported'" >&2
         exit 1 ;;
    esac
  '';

  meta = {
    description = "Factory Droid CLI: terminal AI coding agent";
    homepage = "https://factory.ai/product/cli";
    changelog = "https://docs.factory.ai/changelog/release-notes";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "droid";
    platforms = [ "x86_64-linux" ];
  };
}
