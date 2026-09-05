# Oh My Pi release pin.
#
# Update procedure:
#   1. Set `version` to the latest stable GitHub release.
#   2. Run `nix store prefetch-file --json <asset-url>` for the OMP binary,
#      LICENSE, and THIRD-PARTY-NOTICES.txt; copy their SRI hashes below.
#   3. Run `nix build .#omp` and the complete desktop system build.
#   4. Verify `omp --version`, `omp --smoke-test`, and completions.
#
# These fixed-output hashes pin the exact official release bytes independently
# of OMP's source flake, its lock file, and its binary cache.
{
  version = "18.1.8";

  sources.x86_64-linux = {
    asset = "omp-linux-x64";
    hash = "sha256-wJ1aecRLZDW1kXt9XIR7CVHUg1HnHbr5/Qa8LihXct0=";
  };

  licenseHash = "sha256-FsRfnWZ0QngfA/oZiRTMOavKpI7F7Y9kRkPlVMovv2M=";
  noticesHash = "sha256-EEFCJEuHgbeCjmSqeaYbA/3xboo0ZCeGR8PYStIsvOA=";
}
