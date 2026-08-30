# Zed Delta — closed-beta client packaged from locally downloaded tarballs.
#
# Upstream distributes this to invited users as a gzipped tarball (FHS layout:
# bin/, lib/, share/) rather than a public release asset, so there is no URL
# for fetchurl. The tarball comes in as the `delta-tarball` flake input
# (`flake = false`); its byte-for-byte identity is enforced by flake.lock, and
# the human-readable version lives beside this file in source-pin.nix.
#
# Why this works on NixOS with almost no patching:
#   - `bin/delta` bundles its non-glibc shared libraries under `lib/` and finds
#     them through RPATH `$ORIGIN/../lib`, which stays valid in the nix store.
#   - Its ELF interpreter (/lib64/ld-linux-x86-64.so.2) is rewritten to the
#     stdenv glibc loader below.
{
  lib,
  stdenv,
  patchelf,
  makeWrapper,
  xdg-utils,
  sqlite,
  # Runtime dlopen() dependencies of the GPUI UI layer, resolved by extending
  # the binary's runpath below.
  wayland,
  vulkan-loader,
  libGL,
  # Keymap data location handed to libxkbcommon via XKB_CONFIG_ROOT (NixOS
  # has no /usr/share/X11/xkb).
  xkeyboard-config,
  # Human-facing beta version (see source-pin.nix).
  version,
  # The beta tarball, resolved through the `delta-tarball` flake input.
  delta-tarball,
}:

stdenv.mkDerivation {
  pname = "delta";
  inherit version;
  src = delta-tarball;

  nativeBuildInputs = [ patchelf makeWrapper ];

  # Rely on the upstream bundle layout (RPATH $ORIGIN/../lib); do not let the
  # generic ELF fixup rewire it, and skip stripping a 160MB proprietary binary
  # that was never meant to be stripped.
  dontPatchELF = true;
  dontStrip = true;

  unpackPhase = ''
    tar -xzf "$src"
    mv Delta delta-unpacked
  '';

  installPhase = ''
    mkdir -p "$out"
    cp -r delta-unpacked/* "$out/"
  '';

  postFixup = ''
    patchelf --set-interpreter "$(cat "$NIX_CC"/nix-support/dynamic-linker)" \
      "$out/bin/delta"
    # Keep the upstream bundle first: its own XCB/xkbcommon libs satisfy the
    # link-time NEEDED entries. Append nixpkgs libraries that GPUI loads with
    # bare-name dlopen() at runtime (libwayland-client, libvulkan, ...) — on
    # NixOS nothing else can answer those lookups.
    # Two ELF traps handled here:
    #   - $ORIGIN must reach the ELF as LITERAL bytes -> single quotes.
    #   - --force-rpath keeps the OLD-style DT_RPATH tag, which (unlike
    #     DT_RUNPATH) propagates transitively — the bundled libs depend on
    #     each other (libxcb -> libXau -> ...) and must resolve them from
    #     the bundle too.
    patchelf --force-rpath --set-rpath '$ORIGIN/../lib:${lib.makeLibraryPath [
      wayland vulkan-loader libGL
    ]}' "$out/bin/delta"

    # GPUI resolves bare-name system libraries and xkb keymap data at runtime;
    # on NixOS both need explicit pointers.
    #
    # NOTE: this must live in postFixup, not postInstall — this derivation
    # overrides installPhase, which drops that phase's post-install hook.
    wrapProgram "$out/bin/delta" \
      --set XKB_CONFIG_ROOT "${xkeyboard-config}/share/X11/xkb" \
      --set XDG_DATA_DIRS "${wayland}/share:$XDG_DATA_DIRS" \
      --suffix PATH : ${
        lib.makeBinPath [
          xdg-utils
          sqlite
        ]
      }
  '';

  # Prove the produced binary actually executes in the build sandbox.
  doInstallCheck = true;
  installCheckPhase = ''
    reported="$("$out/bin/delta" --version)"
    echo "installed delta reports: $reported"
    case "$reported" in
      delta\ ${version}) ;;
      *) echo "version mismatch: pinned ${version}, binary reports '$reported'" >&2
         exit 1 ;;
    esac
  '';

  meta = {
    description = "Multiplayer environment for coding with agents, built on DeltaDB (closed beta)";
    homepage = "https://zed.dev/deltadb";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "delta";
    platforms = [ "x86_64-linux" ];
  };
}
