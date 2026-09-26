{ pkgs, inputs, ... }:
let
  tools = import ../../packages/miata-tooling.nix { inherit pkgs inputs; };
in
{
  home.packages = [ tools.kicad tools.konnect tools.poppler ];
  # Use stdio on demand; no unauthenticated HTTP listener or mutable PCM install.
  # Client registration is separate from package installation.
}
