{ lib }:
lib.recursiveUpdate (import ./base.nix) (import ./solitude.nix)
