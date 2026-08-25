{ ... }:
{
  imports = [
    ../../modules/common
    ../../modules/profiles/gaming.nix
    ./hardware.nix
    ./generated-hardware.nix
    ./storage.nix
  ];

  networking.hostName = "desktop";

  system.stateVersion = "26.05";
}
