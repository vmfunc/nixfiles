{
  inputs,
  pkgs,
  hostname,
  ...
}:
{
  imports = [
    ./hardware.nix
    ./disko.nix

    # framework/12-inch/13th-gen-intel, not the 13-inch variant (missing convertible quirks)
    inputs.nixos-hardware.nixosModules.framework-12-13th-gen-intel

    inputs.disko.nixosModules.disko
  ];

  # boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # systemd in initrd needed for impermanence rollback + tpm2 crypttab unlock
  boot.initrd.systemd.enable = true;

  # framework ec kmod asserts kernel >= 6.10
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # power: ppd, which makes nixos-hardware yield tlp off. enable exactly one
  services.power-profiles-daemon.enable = true;

  hardware.bluetooth.enable = true;

  networking.hostName = hostname;
  networking.networkmanager.enable = true;

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # easystore is exfat
  boot.supportedFilesystems = [ "exfat" ];
  environment.systemPackages = [ pkgs.exfatprogs ];

  # hourly auto-deploy from the promoted deploy branch (nixos system.autoUpgrade branch)
  rice.autoUpdate.enable = true;

  # string on nixos, not the integer darwin uses
  system.stateVersion = "25.11";
}
