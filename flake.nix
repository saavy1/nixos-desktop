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

    herdr = {
      url = "github:herdrdev/herdr/v0.8.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };


    omp = {
      url = "github:can1357/oh-my-pi";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Zed Delta closed-beta tarball, downloaded manually to
    # ~/Downloads/delta-linux-x86_64.tar.gz. A new download is re-pinned with
    # `nix flake update delta-tarball` (narHash in flake.lock enforces the
    # exact bytes); bump `version` in packages/delta/source-pin.nix alongside.
    delta-tarball = {
      url = "path:/home/saavy/Downloads/delta-linux-x86_64.tar.gz";
      flake = false;
    };
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
      nixosConfigurations.desktop = mkHost {
        hostModule = ./hosts/desktop;
      };
    };
}
