{ lib, pkgs, ... }:
{
  environment.systemPackages = [ pkgs.sbctl ];

  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  security.tpm2.enable = true;

  # disko owns the cryptroot device= entry; this only merges the extra opt
  boot.initrd.luks.devices.cryptroot.crypttabExtraOpts = [
    "tpm2-device=auto"
  ];
}
