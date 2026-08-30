# Closed-beta release pins for Zed Delta.
#
# When Zed ships you a fresh tarball:
#   1. download it over the file the `delta-tarball` flake input points at
#      (currently ~/Downloads/delta-linux-x86_64.tar.gz)
#   2. re-pin its bytes:        nix flake update delta-tarball
#   3. set `version` below to what the binary reports afterwards
#      (`delta --version`; Infra can do steps 2-4 for you)
#   4. rebuild the system
#
# Integrity note: the exact bytes installed are enforced by flake.lock
# (the narHash recorded for the `delta-tarball` input), verified at every
# evaluation. This file only carries the human-facing version label.
{
  version = "0.1.1-nightly.20260826.22";
}
