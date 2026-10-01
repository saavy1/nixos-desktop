# Shared by Home Manager and the Miata dev shell; desktop flake owns tool pins.
{ pkgs, inputs }:
let
  rustPkgs = pkgs.extend inputs.rust-overlay.overlays.default;
in
{
  kicad = pkgs.kicad;
  konnect = pkgs.symlinkJoin {
    name = "konnect-0.12.0-kicad10";
    paths = [ inputs.konnect.packages.${pkgs.stdenv.hostPlatform.system}.konnect ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/konnect \
        --set KICAD10_SYMBOL_DIR "${pkgs.kicad.libraries.symbols}/share/kicad/symbols" \
        --prefix PATH : "${pkgs.kicad}/bin"
    '';
  };
  # Inspect/export source scans and review generated PDFs without pip installs.
  poppler = pkgs.poppler-utils;
  python = pkgs.python3.withPackages (ps: [ ps.pymupdf ]);
  # One release for the compiler, Cargo, formatter, lints and language server.
  rust = rustPkgs.rust-bin.stable.latest.default.override {
    extensions = [ "rust-analyzer" "rust-src" ];
  };
  # The full package includes Pango/Cairo plugins for dot -Tpdf:cairo.
  graphviz = pkgs.graphviz;
}
