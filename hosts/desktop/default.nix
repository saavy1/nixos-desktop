{ ... }:
{
  imports = [
    ../../modules/common
    ./hardware.nix
    ./storage.nix
  ];

  networking.hostName = "desktop";

  system.stateVersion = "26.05";
}
