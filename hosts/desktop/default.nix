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

  # Sandboxed Hermes workers (kanban/cron) run in a single-uid user namespace,
  # where nix store files owned by host root appear as 65534. OpenSSH refuses
  # the root-owned systemd ssh-proxy include in the default client config
  # ("Bad owner or permissions on .../20-systemd-ssh-proxy.conf") before any
  # connection attempt. The plugin only serves ssh .host / unix:/ vsock:/
  # machine:/ schemes, which nothing on this fleet uses.
  programs.ssh.systemd-ssh-proxy.enable = false;

  networking.firewall.interfaces.eno1.allowedUDPPorts = [ 5353 ];

  system.stateVersion = "26.05";
}
