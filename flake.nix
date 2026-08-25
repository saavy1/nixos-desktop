{
  description = "Reusable NixOS configuration for personal machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    hermes-desktop.url = "github:NousResearch/hermes-agent/v2026.8.19";

    omp = {
      url = "github:can1357/oh-my-pi";
      inputs.nixpkgs.follows = "nixpkgs";
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
