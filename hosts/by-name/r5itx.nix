{
  config,
  pkgs,
  lib,
  self,
  ...
}:
{
  imports = [
    ../../devices/by-name/nixos-radxa-rock-5-itx.nix
    ../../profiles/desktop.nix
    ../../profiles/common.nix
  ];

  # Headless server — override desktop.nix
  services.xserver.enable = lib.mkForce false;
  services.desktopManager.plasma6.enable = lib.mkForce false;
}
