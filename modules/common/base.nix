{ lib, pkgs, ... }:
{
  time.timeZone = "America/Denver";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Zed's official flake builds from source; its cachix substitutes the
  # artifacts it holds (toolchain deps and CI-built outputs). Appended so
  # cache.nixos.org keeps priority.
  nix.settings.substituters = lib.mkAfter [ "https://zed.cachix.org" ];
  nix.settings.trusted-public-keys = lib.mkAfter [
    "zed.cachix.org-1:/pHQ6dpMsAZk2DiP4WCL0p9YDNKWj2Q5FL20bNmw1cU="
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
      "chatgpt-app"
      "droid"
      "claude-desktop"
      "moshi-hook"
      "polylane"
      "aseprite"
      "ssbm-nucleus"
    ];

  environment.systemPackages = [
    pkgs.bubblewrap
    pkgs.git
    pkgs.jq
  ];

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
