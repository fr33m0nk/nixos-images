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
      # Use the target kernel (linux_rockchip64_7_1) for the disko VM
      # instead of the host's default.  The target kernel has BTRFS in
      # its initrd via boot.initrd.kernelModules, which the host kernel
      # may not support (e.g. Lima NixOS VMs where modprobe is restricted).
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
