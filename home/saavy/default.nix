{ pkgs, ... }:
{
  imports = [
    ./applications.nix
    ./hyprland.nix
  ];

  home = {
    username = "saavy";
    homeDirectory = "/home/saavy";
    stateVersion = "26.05";
    packages = [ pkgs.ghostty ];
  };

  programs.home-manager.enable = true;
}
