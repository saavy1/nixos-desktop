# Select a palette from ./palettes by name.
{
  lib,
  name ? "solitude",
}:
import ./mk-theme.nix { inherit lib; } (import (./palettes + "/${name}.nix"))
