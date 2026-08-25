{ pkgs, ... }:
{
  time.timeZone = "America/Denver";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  networking.networkmanager.enable = true;

  services.tailscale.enable = true;

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

  programs.fish.enable = true;

  users.groups.saavy.gid = 1000;
  users.users.saavy = {
    isNormalUser = true;
    uid = 1000;
    group = "saavy";
    shell = pkgs.fish;
    extraGroups = [ "wheel" ];
  };
}
