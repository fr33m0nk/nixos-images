{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../profiles/rk3588.nix
    ../../profiles/btrfs.nix
  ];

  system.stateVersion = "26.11";

  networking.hostName = lib.mkDefault "r5itx";

  disko = {
    bootImage = {
      partLabel = lib.mkDefault "NVME";
      primaryStart = "1M";
      uboot = {
        enable = false;
        package = pkgs.buildUBootRk3588 {
          withSpi = true;
          dtsFile = config.hardware.deviceTree.dtsFile;
          extraConfig = ''
            CONFIG_CLK_GPIO=y
          '';
        };
      };
    };
  };

  hardware = {
    deviceTree = {
      name = "rockchip/rk3588-rock-5-itx.dtb";
      platform = "rockchip";
      dtsFile = ../../dts/mainline/rockchip/rk3588-rock-5-itx.dts;
      overlays = [
        # M.2 E-key SATA breakout: switches combphy0_ps from PCIe → SATA mode
        {
          name = "rock-5-itx-m2e-sata";
          dtsFile = ../../dts/mainline/overlays/rock-5-itx-m2e-sata.dtso;
        }
      ];
    };
  };
}
