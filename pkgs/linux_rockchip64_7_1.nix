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
    map
      (p: {
        name = baseNameOf p;
        patch = p;
      })
      (
        builtins.filter (p: lib.hasSuffix ".patch" (toString p)) (
          lib.filesystem.listFilesRecursive ../patches/kernel
        )
      );

  structuredExtraConfig = with lib.kernel; {
    # FW_LOADER
    FW_LOADER_COMPRESS = yes;
    FW_LOADER_COMPRESS_ZSTD = yes;
    # PCIE PHY
    PHY_ROCKCHIP_SNPS_PCIE3 = yes;
    # MPTCP
    MPTCP = yes;
    INET_MPTCP_DIAG = module;
    # RKVENC (VEPU580) H.264/H.265 hardware encoder (dual-core RKVENC via MPP)
    VIDEO_ROCKCHIP_RKVENC = module;
    # RKVDEC2 (VDPU381) H.264/HEVC/VP9 hardware decoder (MPP, /dev/mpp_service)
    VIDEO_ROCKCHIP_RKVDEC2 = module;
  };

  enableCommonConfig = false;
  extraConfig = "";
  ignoreConfigErrors = true;
  autoModules = false;
  extraMeta.platforms = [ "aarch64-linux" ];
}
