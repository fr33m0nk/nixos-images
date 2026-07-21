{
  config,
  lib,
  pkgs,
  ...
}:
{
  nixpkgs = {
    system = "aarch64-linux";
  };

  disko = {
    bootImage = {
      primaryStart = lib.mkIf config.disko.bootImage.uboot.enable "16M";
      uboot = {
        enable = lib.mkDefault true;
        imageFile = "u-boot-rockchip.bin";
        seek = 64;
        package = lib.mkDefault (
          pkgs.buildUBootRk3588 {
            dtsFile = config.hardware.deviceTree.dtsFile;
          }
        );
      };
    };
  };

  hardware = {
    enableAllHardware = false;
    wirelessRegulatoryDatabase = true;
    deviceTree = {
      enable = true;
      overlays = [
        {
          name = "rkvenc-mpp";
          dtsFile = ../dts/mainline/overlays/rk3588-rkvenc-mpp.dtso;
        }
        {
          name = "rkvdec-mpp";
          dtsFile = ../dts/mainline/overlays/rk3588-rkvdec-mpp.dtso;
        }
      ];
    };
    firmware = [
      pkgs.rockchip-firmware
    ];
    serial = {
      enable = lib.mkDefault true;
      unit = 2;
      baudrate = 1500000;
    };
  };

  boot = {
    kernelPackages = lib.mkDefault (pkgs.linuxPackagesFor pkgs.linux_rockchip64_7_1);
    kernelParams = [
      "net.ifnames=0"
      # The VDPU381 decoder's internal MMU walks the IOMMU page table
      # unbounded from IOVA 0 — a hardware behaviour that the BSP kernel
      # stops via rockchip_iommu_disable/enable (not in mainline).  Run
      # IOMMU in passthrough so the walker sees physical memory instead
      # of faulting, and bump swiotlb so decode DMA buffers (1 MiB each)
      # don't overflow the default 64 MiB bounce pool.
      "iommu.passthrough=1"
      "swiotlb=131072"
    ];
    initrd.allowMissingModules = !config.boot.kernelPackages.kernel.configfile.autoModules;
  };

  services = {
    # Cap Mali-G610 GPU at 800 MHz — panthor devfreq exposes
    # 900/1000 MHz OPPs programmatically (bypassing DT overlay).
    # Those frequencies are unstable on many RK3588 chips, causing
    # CSG suspend timeout panics.  udev fires when devfreq appears.
    udev.extraRules = ''
      SUBSYSTEM=="devfreq", KERNEL=="fb000000.gpu", ATTR{max_freq}="800000000"

      # Rockchip MPP / VPU device access for the `video` group, so rootless MPP
      # (mpi_dec_test, ffmpeg-rockchip, a Jellyfin container) can use the codec
      # hardware without root. The `render` node covers OpenCL tonemap / RGA.
      KERNEL=="mpp_service", GROUP="video", MODE="0660"
      KERNEL=="rga", GROUP="video", MODE="0660"
      SUBSYSTEM=="dma_heap", KERNEL=="system", GROUP="video", MODE="0660"
      KERNEL=="renderD128", GROUP="render", MODE="0660"
    '';

    usb-rndis.enable = lib.mkDefault true;

    pipewire.wireplumber.extraConfig = {
      rk3588-sound = {
        "monitor.alsa.rules" = [
          {
            matches = [
              {
                "device.name" = "alsa_card.platform-hdmi0-sound";
              }
            ];
            actions = {
              update-props = {
                "device.description" = "HDMI 0";
                "device.form-factor" = "hdmi";
                "device.icon-name" = "video-display";
              };
            };
          }
          {
            matches = [
              {
                "device.name" = "alsa_card.platform-hdmi1-sound";
              }
            ];
            actions = {
              update-props = {
                "device.description" = "HDMI 1";
                "device.form-factor" = "hdmi";
                "device.icon-name" = "video-display";
              };
            };
          }
          {
            matches = [
              {
                "device.name" = "alsa_card.platform-analog-sound";
              }
            ];
            actions = {
              update-props = {
                "device.description" = "Cuffie / Line Out";
              };
            };
          }
          {
            matches = [
              {
                "node.name" = "alsa_output.platform-hdmi0-sound.stereo-fallback";
              }
            ];
            actions = {
              update-props = {
                "node.description" = "HDMI 0 (LG TV)";
                "node.nick" = "HDMI 0";
              };
            };
          }
        ];
      };
    };
  };

  environment = {
    variables = {
      ALSA_CONFIG_UCM2 = "${pkgs.alsa-ucm-conf-rk3588}/share/alsa/ucm2";
    };
    systemPackages = with pkgs; [
      usbutils
      pciutils
      i2c-tools
      libgpiod
      minicom
      ethtool
      vim
      rktop
    ];
  };
}
