# Polylane CLI — production observability for coding agents (https://polylane.com).
#
# Upstream ships a single self-contained ESM bundle, `polylane.mjs`, attached
# to GitHub releases of coreplanelabs/cli; it needs Node.js 20+. The official
# installer (curl -fsSL https://polylane.com/install.sh | bash) downloads that
# same asset, verifies the release digest, and then runs interactive,
# per-user steps (`polylane setup`, `polylane auth login`, MCP key minting,
# agent skills). Only the download is declarative here; run those steps by
# hand after switching — they write ~/.polylane and agent configs.
#
# Update: bump `version`, then `nix store prefetch-file --json <asset-url>`
# and confirm its hash matches the release's published sha256 digest.
{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs,
}:
let
  version = "0.2.42";
in
stdenvNoCC.mkDerivation {
  pname = "polylane";
  inherit version;

  src = fetchurl {
    url = "https://github.com/coreplanelabs/cli/releases/download/v${version}/polylane.mjs";
    hash = "sha256-sNezlmbQ5+tCQ164O6MikpiqATVtRBHBzWZ4YxPz0ug=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontUnpack = true;

  # Keep the .mjs extension: Node selects ESM by it (upstream relies on this
  # for Node < 22.7, which has no module-syntax detection).
  installPhase = ''
    install -Dm644 "$src" "$out/lib/polylane/polylane.mjs"
    makeWrapper ${lib.getExe nodejs} "$out/bin/polylane" \
      --add-flags "$out/lib/polylane/polylane.mjs"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    reported="$(HOME="$TMPDIR" "$out/bin/polylane" --version)"
    echo "installed polylane reports: $reported"
    [ "$reported" = "polylane ${version}" ] || {
      echo "version mismatch: pinned ${version}, CLI reports '$reported'" >&2
      exit 1
    }
  '';

  meta = {
    description = "Polylane CLI: production context for coding agents";
    homepage = "https://polylane.com";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    mainProgram = "polylane";
    platforms = lib.platforms.linux;
  };
}
