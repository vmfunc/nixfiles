# minnow (framework 12): PLACEHOLDER hardware config so the host evals before
# the box is adopted. the by-label devices below match a stock installer layout
# ONLY so eval passes; do not switch the real box on them.
# TODO(deploy): replace at migration. target posture mirrors guppy: gpt -> ESP
# + luks2 (cryptroot: fido2 keyslot + recovery key in the vault, no passphrase)
# -> lvm swap+root, systemd-stage-1 for the fido2 crypttab options, resumeDevice
# on the encrypted swap LV. if the interim install on the box is unencrypted,
# that means a re-disk (nixos-anywhere + disko); if it is already luks, lift its
# real uuids via `nixos-generate-config --show-hardware-config` and add the
# fido2 keyslot with `systemd-cryptenroll --fido2-device=auto`.
{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.kernelModules = [ "kvm-intel" ];

  # systemd-stage-1 now so the eventual luks2 fido2 crypttab options work
  # without another initrd flavor flip at migration.
  boot.initrd.systemd.enable = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
