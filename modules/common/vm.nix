{ lib, ... }:
{
  virtualisation.vmVariant = {
    security.sudo.wheelNeedsPassword = false;
    services.btrfs.autoScrub.enable = lib.mkForce false;
    services.smartd.enable = lib.mkForce false;

    users.users.saavy.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIImp8BGx3xh8lUwIrJ/DoPa/O6j/sUCp1TKlbScR59qq jayson@saavylab.com"
    ];
    networking.firewall.interfaces.eth0.allowedTCPPorts = [ 22 ];

    virtualisation = {
      cores = 4;
      memorySize = 4096;
      diskSize = 8192;
      graphics = true;
      forwardPorts = [
        {
          from = "host";
          host = {
            address = "127.0.0.1";
            port = 22222;
          };
          guest.port = 22;
        }
      ];
    };
  };
}
