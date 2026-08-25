{ ... }:
{
  imports = [
    ./applications.nix
    ./hyprland.nix
    ./idle-lock.nix
    ./swaync.nix
    ./theme
  ];

  home = {
    username = "saavy";
    homeDirectory = "/home/saavy";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
