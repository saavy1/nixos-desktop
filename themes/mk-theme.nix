# Builds a full theme from a palette: palette values override ./base.nix.
# Consumers read semantic roles from `color` (surface, text, accent, status).
{ lib }:
palette: lib.recursiveUpdate (import ./base.nix) palette
