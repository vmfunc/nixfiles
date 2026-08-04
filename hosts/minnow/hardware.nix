# minnow (framework 12, 13th-gen intel i5-1334U): hand-written against the disk
# layout this install created on 2026-08-03, same shape as guppy. layout: gpt ->
# 1G ESP + luks2 (cryptroot, argon2id) -> lvm vg "minnow" -> 52G swap + ext4
# root. the luks keyslots after setup: yubikey fido2 (primary) + recovery key
# (in azzie's vault); the temp install passphrase is removed post-enroll.
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
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # systemd-stage-1 is what implements crypttab token options; the script initrd
  # cannot do fido2. token-timeout falls through to the passphrase/recovery-key
  # prompt after 10s so a lost/absent yubikey never hard-locks boot.
  boot.initrd.systemd.enable = true;
  boot.initrd.luks.devices.cryptroot = {
    device = "/dev/disk/by-uuid/487ef5f0-2e34-45bd-9f77-a3065b01b5ff";
    crypttabExtraOpts = [
      "fido2-device=auto"
      "token-timeout=10"
    ];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/f7fe790d-1f7e-4a46-a17d-ca2615f4055e";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/9179-1AD6";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/2f9c6461-4ab7-4b0d-84aa-c5a472621bcb"; }
  ];
  # swap LV sits inside the same luks volume, so hibernate resume happens after
  # the fido2 unlock; 52G covers the 48G RAM image. logind wires the lid to
  # suspend-then-hibernate in default.nix.
  boot.resumeDevice = "/dev/disk/by-uuid/2f9c6461-4ab7-4b0d-84aa-c5a472621bcb";

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
