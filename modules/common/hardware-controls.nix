{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  hardware.i2c.enable = true;
  services.power-profiles-daemon.enable = true;

  users.users.saavy.extraGroups = [
    "i2c"
    "video"
  ];
}
