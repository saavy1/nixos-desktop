{ ... }:
{
  imports = [
    ./agents.nix
    ./applications.nix
    ./editor.nix
    ./git.nix
    ./hardware-controls.nix
    ./hyprland.nix
    ./idle-lock.nix
    ./quickshell.nix
    ./theme
  ];

  home = {
    username = "saavy";
    homeDirectory = "/home/saavy";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
