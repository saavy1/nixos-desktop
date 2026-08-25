{ pkgs, ... }:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
  };

  programs.gamescope.enable = true;
  programs.gamemode.enable = true;

  environment.systemPackages = [ pkgs.vulkan-tools ];
}
