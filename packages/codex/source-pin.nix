# OpenAI Codex standalone release pin.
#
# Update procedure:
#   1. Set `version` to the desired stable release.
#   2. Run `nix store prefetch-file --json <release-url>` and copy its `hash`
#      value below.
#   3. Build the complete desktop system.
#   4. Verify `codex --version`, bundled helpers, and the full NixOS build.
#
# The URL is derived from this version and target. The fixed-output hash pins
# the exact official release bytes independently of nixpkgs and its cache.
{
  version = "0.153.2";

  sources.x86_64-linux = {
    target = "x86_64-unknown-linux-musl";
    hash = "sha256-4Q+gzueOnwvTlYgPA/1P0ifZA8p69km7wI0WSRAekiU=";
  };
}
