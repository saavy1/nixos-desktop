{
  boot.loader.limine.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "btrfs";
    options = [
      "subvol=@root"
      "compress=zstd:3"
      "noatime"
      "discard=async"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "btrfs";
    options = [
      "subvol=@home"
      "compress=zstd:3"
      "noatime"
      "discard=async"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/NIXOS";
    fsType = "btrfs";
    options = [
      "subvol=@nix"
      "compress=zstd:3"
      "noatime"
      "discard=async"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXBOOT";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/" ];
  };
}
