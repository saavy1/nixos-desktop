{
  zramSwap.enable = true;
  services.fwupd.enable = true;

  services.smartd = {
    enable = true;
    notifications.systembus-notify.enable = true;
  };
}
