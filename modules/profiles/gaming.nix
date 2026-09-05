{ pkgs, ... }:
let
  nkit = pkgs.callPackage ../../packages/nkit { };
  slippi-launcher = pkgs.callPackage ../../packages/slippi-launcher { };
in
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
  };

  programs.gamescope.enable = true;
  programs.gamemode.enable = true;

  # Native GameCube controller adapters in Wii U / Switch mode. TAG+=uaccess
  # grants the active local seat access without making the USB device globally
  # writable as Slippi's generic Linux instructions do with MODE=0666.
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="057e", ATTR{idProduct}=="0337", TAG+="uaccess"
  '';

  environment.systemPackages = with pkgs; [
    heroic
    nkit
    p7zip
    slippi-launcher
    vulkan-tools
  ];
}
