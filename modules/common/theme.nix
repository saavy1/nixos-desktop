{ lib, pkgs, ... }:
let
  theme = import ../../themes { inherit lib; };
in
{
  _module.args.theme = theme;

  fonts.packages = map (
    path: lib.getAttrFromPath (lib.splitString "." path) pkgs
  ) theme.typography.packages;
}
