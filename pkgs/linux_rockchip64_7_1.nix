{
  lib,
  fetchurl,
  buildLinux,
  linux_7_1,
  ...
}:
buildLinux {
  inherit (linux_7_1) version src;

  defconfigFile = fetchurl {
    url = "https://raw.githubusercontent.com/armbian/build/559a605841fb02592d8a2db3edd614d80dd236aa/config/kernel/linux-rockchip64-edge.config";
    hash = "sha256-vdUMm0mBtzlSHawpnVkLOfLUOlnKlMx7kxvzR7pH1mg=";
  };

  kernelPatches =
    let
      allPatches = builtins.filter (p: lib.hasSuffix ".patch" (toString p)) (
        lib.filesystem.listFilesRecursive ../patches/kernel
      );
      # Patches excluded due to conflicts:
      #   0005-rockchip-rk3588-hdmirx-audio.patch — hunk #3 conflicts with #0002+#0003; needs rebase
      excludedNames = [
        "0005-rockchip-rk3588-hdmirx-audio.patch"
      ];
      isExcluded = p: builtins.elem (baseNameOf (toString p)) excludedNames;
      usablePatches = builtins.filter (p: !(isExcluded p)) allPatches;
      # Ensure rcawston patches are ordered first (before other patches that touch same DTSI)
      rcawstonNames = [
        "0001-rockchip-rk3588-vepu580-encoder-support-v3.patch"
        "0002-rockchip-rk3588-hdmirx-edid-fix-v1.patch"
        "0003-rockchip-rk3588-hdmirx-plugout-fix-v1.patch"
      ];
      isRcawston = p: builtins.elem (baseNameOf (toString p)) rcawstonNames;
      rcawstonPatches = builtins.filter isRcawston usablePatches;
      otherPatches = builtins.filter (p: !(isRcawston p)) usablePatches;
    in
    map (p: { name = baseNameOf p; patch = p; }) (rcawstonPatches ++ otherPatches);

  structuredExtraConfig = with lib.kernel; {
    # FW_LOADER
    FW_LOADER_COMPRESS = yes;
    FW_LOADER_COMPRESS_ZSTD = yes;
    # PCIE PHY
    PHY_ROCKCHIP_SNPS_PCIE3 = yes;
    # MPTCP
    MPTCP = yes;
    INET_MPTCP_DIAG = module;
    # RK3588 VEPU580 H.265/H.264 encoder (rcawston patches)
    VIDEO_ROCKCHIP_RKVENC = module;
  };

  # rcawston patches applied: VEPU580 encoder (#0001), HDMIRX EDID (#0002), HDMIRX plugout (#0003)
  # HDMI-RX audio (#0005) disabled — hunk conflict with patches #0002+#0003
  enableCommonConfig = false;
  extraConfig = "";
  ignoreConfigErrors = true;
  autoModules = false;
  extraMeta.platforms = [ "aarch64-linux" ];
}
