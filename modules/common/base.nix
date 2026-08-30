{ lib, pkgs, ... }:
{
  time.timeZone = "America/Denver";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "discord"
      "discord-unwrapped"
      "spotify"
      "spotify-unwrapped"
      "delta"
      "steam"
      "steam-original"
      "steam-run"
      "steam-unwrapped"
      "droid"
    ];

  environment.systemPackages = [ pkgs.git ];

  networking.networkmanager.enable = true;

  services.tailscale = {
    enable = true;
    extraSetFlags = [ "--operator=saavy" ];
  };

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
    linger = true;
    group = "saavy";
    shell = pkgs.fish;
    extraGroups = [ "wheel" ];
  };
}
