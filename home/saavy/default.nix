{ ... }:
{
  imports = [
    ./agents.nix
    ./applications.nix
    ./editor.nix
    ./git.nix
    ./hyprland.nix
    ./idle-lock.nix
    ./swaync.nix
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
