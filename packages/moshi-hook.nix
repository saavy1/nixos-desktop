{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "moshi-hook";
  version = "0.3.13";

  src = fetchurl {
    url = "https://cdn.getmoshi.app/hook/v${finalAttrs.version}/moshi-hook_Linux_x86_64.tar.gz";
    hash = "sha256-l1ktxkyTTASjjG4TEdLF9ygBAXDhGc4B9FPGHX3bwsM=";
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    install -Dm755 moshi-hook "$out/bin/moshi-hook"
    ln -s moshi-hook "$out/bin/moshi"

    # Generate Moshi's embedded Hermes plugin for declarative linking.
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME/.hermes"
    "$out/bin/moshi-hook" install --target hermes
    install -Dm644 "$HOME/.hermes/plugins/moshi-hooks/plugin.yaml" \
      "$out/share/hermes/moshi-hooks/plugin.yaml"
    install -Dm644 "$HOME/.hermes/plugins/moshi-hooks/__init__.py" \
      "$out/share/hermes/moshi-hooks/__init__.py"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    "$out/bin/moshi-hook" version | grep -F "${finalAttrs.version}"
  '';

  meta = {
    description = "Moshi daemon and hooks for AI agent approval round-trips";
    homepage = "https://getmoshi.app";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "moshi-hook";
    platforms = [ "x86_64-linux" ];
  };
})
