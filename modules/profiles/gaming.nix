{ pkgs, ... }:
let
  nkit = pkgs.callPackage ../../packages/nkit { };
  proton-ge-10-34 = pkgs.callPackage ../../packages/proton-ge-10-34 { };
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
    extraCompatPackages = [
      pkgs.proton-ge-bin
      proton-ge-10-34
    ];
  };

  programs.gamescope.enable = true;
  programs.gamemode.enable = true;

  # Slippi Playback's downloaded AppImage also runs outside Launcher's FHS
  # wrapper (for example, from the render harness). Keep its bytes unpatched.
  programs.nix-ld.libraries = with pkgs; [
    alsa-lib
    fontconfig
    freetype
    fribidi
    gdk-pixbuf
    glib
    gmp
    harfbuzz
    libdrm
    libglvnd
    libgpg-error
    librsvg
    libSM
    libusb1
    libX11
    libxcb
    p11-kit
    pango
  ];

  # Native GameCube controller adapters in Wii U / Switch mode. TAG+=uaccess
  # grants the active local seat access without making the USB device globally
  # writable as Slippi's generic Linux instructions do with MODE=0666.
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="057e", ATTR{idProduct}=="0337", TAG+="uaccess"
  '';

  environment.systemPackages = with pkgs; [
    heroic
    moonlight-qt
    nkit
    p7zip
    slippi-launcher
    vulkan-tools
  ];
}
