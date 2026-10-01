{
  description = "Reusable NixOS configuration for personal machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # No `follows`: upstream hardcodes an Electron-headers sha256 against
    # the electron version of its OWN pinned nixpkgs (nix/desktop.nix).
    # Forcing our nixpkgs in breaks that hash whenever either side bumps
    # electron. Upstream CI validates this exact lock. Update with
    # `nix flake update hermes-agent` or a full `nix flake update`; avoid a
    # lone `nix flake update nixpkgs` while the two pins coincide, or
    # hermes inherits an electron its sha rejects.
    hermes-agent.url = "github:NousResearch/hermes-agent";

    # Follow upstream CUA development rather than a release tag. flake.lock
    # records the reproducible snapshot; `nix flake update cua` advances it.
    # Upstream's Nix build includes the portal/libei and wlroots Wayland paths.
    cua.url = "github:trycua/cua";

    # KiCad 10 MCP server; keep upstream's tested Rust/nixpkgs toolchain.
    konnect.url = "github:mixelpixx/Konnect/v0.12.0";

    # Rust toolchains for local projects such as ~/dev/miata, independent of
    # Konnect's pin. `nix flake update rust-overlay` advances to newer stable.
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    herdr = {
      url = "github:herdrdev/herdr/v0.9.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };


    omp = {
      url = "github:can1357/oh-my-pi";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Zed Delta, packaged upstream by the official delta-nix flake: fetchurl
    # against the hash-pinned stable release, patchelf wrapping, and desktop
    # entries routed through the CLI. No `follows`: upstream builds against
    # its own nixpkgs pin (wrapper/runtime libs) validated by its CI lock.
    # Advance the release with `nix flake update delta`; pin a tag
    # (`github:zed-industries/delta-nix/v0.18.0`) to hold an exact version.
    delta.url = "github:zed-industries/delta-nix";

    # Zed editor from the official in-repo flake. It builds from source with
    # upstream's own crane/rust toolchain and nixpkgs pins (insulated from
    # ours), and zed.cachix.org substitutes whatever it holds — see the
    # substituter entry in modules/common/base.nix. Pinned to a release tag
    # on purpose: this flake has no binary channel, so a moving ref would
    # recompile the Rust workspace on every `nix flake update`. Bump the
    # tag deliberately; the cost is one long local build per release.
    zed.url = "github:zed-industries/zed/v1.22.0";
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      mkHost =
        {
          hostModule,
          system ? "x86_64-linux",
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [ hostModule ];
        };
    in
    {
      packages.x86_64-linux.miata-tooling = nixpkgs.legacyPackages.x86_64-linux.symlinkJoin {
        name = "miata-tooling";
        paths = builtins.attrValues (import ./packages/miata-tooling.nix {
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          inherit inputs;
        });
      };
      packages.x86_64-linux.claude-desktop =
        nixpkgs.legacyPackages.x86_64-linux.callPackage ./packages/claude-desktop { };

      nixosConfigurations.desktop = mkHost {
        hostModule = ./hosts/desktop;
      };
    };
}
