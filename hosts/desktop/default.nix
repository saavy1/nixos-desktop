{ ... }:
{
  imports = [
    ./base.nix
    ./hardware.nix
    ./storage.nix
    ./vm.nix
  ];

  networking.hostName = "desktop";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "26.05";
}
