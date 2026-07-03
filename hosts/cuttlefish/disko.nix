# @-subvol names must match modules/nixos/impermanence.nix wipe-on-boot
{ ... }:
{
  disko.devices.disk.main = {
    type = "disk";
    # TODO(deploy): set the real /dev/disk/by-id/nvme-<model>_<serial> (PROVISIONING.md step 0).
    # by-id, never /dev/nvme0n1: enum order is unstable and --mode destroy wipes the wrong disk
    device = "/dev/disk/by-id/nvme-REPLACE_ME_WITH_REAL_DISK_ID";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            # no keyFile/passwordFile = interactive passphrase prompt; secureboot.nix
            # adds tpm2 auto-unlock on top, this stays the recovery slot
            settings = {
              # allowDiscards leaks rough used-space on ciphertext at rest; fine for a daily laptop
              allowDiscards = true;
            };
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              # the initrd rollback (modules/nixos/impermanence.nix) restores /
              # from @blank, but subvolumes below only creates @; snapshot it at
              # disko time so a missed manual step can't fail the first-boot
              # rollback (PROVISIONING.md must-do #2)
              postCreateHook = ''
                (
                  MNTPOINT=$(mktemp -d)
                  mount /dev/mapper/cryptroot "$MNTPOINT" -o subvol=/
                  trap 'umount "$MNTPOINT"; rm -rf "$MNTPOINT"' EXIT
                  if ! btrfs subvolume show "$MNTPOINT/@blank" >/dev/null 2>&1; then
                    btrfs subvolume snapshot -r "$MNTPOINT/@" "$MNTPOINT/@blank"
                  fi
                )
              '';
              subvolumes = {
                "@" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@persist" = {
                  mountpoint = "/persist";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                # hibernate/resume needs boot.resumeDevice + resume_offset, not auto-generated
                "@swap" = {
                  mountpoint = "/swap";
                  swap.swapfile.size = "16G";
                };
              };
            };
          };
        };
      };
    };
  };
}
