{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    "${modulesPath}/profiles/minimal.nix"
  ];

  system = {
    firstLoginSetup.enable = true;
    passless.enable = true;
    symlinkConfig.enable = true;
  };

  disko = {
    imageBuilder = {
      enableBinfmt = config.disko.imageBuilder.pkgs != pkgs;
      # Use the target kernel so BTRFS (built-in via CONFIG_BTRFS_FS=y)
      # is always available, even on hosts where insmod is blocked.
      kernelPackages = pkgs.linuxPackagesFor pkgs.linux_rockchip64_7_1;
    };
  };

  boot = {
    growPartition.enable = true;
    espRelocation.enable = true;
    loader.grub.btrfsPackage = config.disko.imageBuilder.pkgs.btrfs-progs;
    initrd.availableKernelModules = lib.mkIf config.hardware.enableAllHardware [
      "mpt3sas"
      "hv_storvsc"
    ];
  };

  hardware.enableAllHardware = lib.mkDefault true;

  services.getty.autologinUser = "root";

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };
}
