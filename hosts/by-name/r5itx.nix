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

  # Headless server — nuke everything desktop.nix enables
  hardware.graphics.enable = lib.mkForce false;
  services.xserver.enable = lib.mkForce false;
  services.desktopManager.plasma6.enable = lib.mkForce false;
  services.displayManager.plasma-login-manager.enable = lib.mkForce false;
  services.displayManager.sddm.enable = lib.mkForce false;
  services.displayManager.autoLogin.enable = lib.mkForce false;
  services.displayManager.defaultSession = lib.mkForce "none";
}
