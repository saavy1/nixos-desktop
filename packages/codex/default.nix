# OpenAI Codex CLI packaged directly from the official standalone bundle.
#
# This intentionally does not inherit nixpkgs' Codex version: coding harnesses
# move quickly, so the release and bytes are pinned locally in source-pin.nix.
{
  autoPatchelfHook,
  fetchurl,
  lib,
  ncurses,
  stdenv,
}:
let
  pin = import ./source-pin.nix;
  source =
    pin.sources.${stdenv.hostPlatform.system}
      or (throw "Codex is not pinned for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "codex";
  inherit (pin) version;

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${pin.version}/codex-package-${source.target}.tar.gz";
    inherit (source) hash;
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ ncurses ];

  # Preserve OpenAI's release binaries. autoPatchelf only repairs the bundled
  # dynamically linked zsh for NixOS; Codex, its host, rg, and bwrap are static.
  dontStrip = true;

  unpackPhase = ''
    runHook preUnpack
    mkdir source
    tar -xzf "$src" -C source
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r source/. "$out/"

    mkdir -p \
      "$out/share/bash-completion/completions" \
      "$out/share/fish/vendor_completions.d" \
      "$out/share/zsh/site-functions"
    "$out/bin/codex" completion bash > "$out/share/bash-completion/completions/codex"
    "$out/bin/codex" completion fish > "$out/share/fish/vendor_completions.d/codex.fish"
    "$out/bin/codex" completion zsh > "$out/share/zsh/site-functions/_codex"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    reported="$($out/bin/codex --version)"
    echo "installed Codex reports: $reported"
    test "$reported" = "codex-cli ${pin.version}"

    test -x "$out/bin/codex-code-mode-host"
    "$out/codex-path/rg" --version >/dev/null
    "$out/codex-resources/bwrap" --version >/dev/null
    "$out/codex-resources/zsh/bin/zsh" --version >/dev/null
  '';

  meta = {
    description = "OpenAI coding agent CLI, pinned from the official standalone release";
    homepage = "https://github.com/openai/codex";
    changelog = "https://github.com/openai/codex/releases/tag/rust-v${pin.version}";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "codex";
    platforms = builtins.attrNames pin.sources;
  };
}
