{ ... }:
{
  imports = [
    ./hardware.nix
    ./storage.nix
  ];

  networking.hostName = "desktop";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "26.05";
}
