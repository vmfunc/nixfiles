{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.sbctl ];

  # lanzaboote signs and installs its own stub, so systemd-boot stays off or the
  # two modules would double-manage the ESP. plain false, nothing else sets it.
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;

  # TODO(deploy): sbctl create-keys, rebuild, then sbctl enroll-keys --microsoft
  # (PROVISIONING.md step 3)
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  security.tpm2.enable = true;

  # disko owns the cryptroot device= entry; this only merges the extra opt
  # TODO(deploy): systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=0+2+7
  # --tpm2-with-pin=yes (PROVISIONING.md step 4)
  boot.initrd.luks.devices.cryptroot.crypttabExtraOpts = [
    "tpm2-device=auto"
  ];
}
