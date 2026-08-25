{
  virtualisation.vmVariant = {
    services.getty.autologinUser = "saavy";
    security.sudo.wheelNeedsPassword = false;

    virtualisation = {
      cores = 4;
      memorySize = 4096;
      diskSize = 8192;
      graphics = true;
    };
  };
}
