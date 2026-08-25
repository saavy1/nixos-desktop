{ ... }:
{
  imports = [
    ./applications.nix
    ./hyprland.nix
    ./theme.nix
  ];

  home = {
    username = "saavy";
    homeDirectory = "/home/saavy";
    stateVersion = "26.05";
  };

  programs.home-manager.enable = true;
}
