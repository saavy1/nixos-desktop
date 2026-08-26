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

  networking.firewall.interfaces.eno1.allowedUDPPorts = [ 5353 ];
  networking.firewall.interfaces.eno1.allowedTCPPorts = [ 9119 ];
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 9119 ];

  system.stateVersion = "26.05";
}
