# guppy (thinkpad t14 gen 6, lunar lake): hand-written against the disk layout
# this install created on 2026-07-29, NOT nixos-generate-config verbatim: the
# generator can't see the fido2 token binding. layout: gpt -> 1G ESP + luks2
# (cryptroot) -> lvm vg "guppy" -> 34G swap + ext4 root. the luks keyslots are
# yubikey fido2 (slot 1) + recovery key (slot 2, in azzie's vault); no passphrase.
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
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # systemd-stage-1 is what implements crypttab token options; the script initrd
  # cannot do fido2. token-timeout falls through to the recovery-key prompt after
  # 10s so a lost/absent yubikey never hard-locks boot.
  boot.initrd.systemd.enable = true;
  boot.initrd.luks.devices.cryptroot = {
    device = "/dev/disk/by-uuid/78378739-8fcf-46bd-8e48-01e6ce42fae0";
    crypttabExtraOpts = [
      "fido2-device=auto"
      "token-timeout=10"
    ];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/50d01bf1-41d7-4415-ae0d-3a1c787a1e48";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/A267-E8FE";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/a9d59701-3908-4413-8ea6-114f6a8fa4b3"; }
  ];
  # swap LV sits inside the same luks volume, so hibernate resume happens after
  # the fido2 unlock; 34G covers the 32G RAM image. logind wires the lid to
  # suspend-then-hibernate in default.nix.
  boot.resumeDevice = "/dev/disk/by-uuid/a9d59701-3908-4413-8ea6-114f6a8fa4b3";

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
