# @-subvol names must match modules/nixos/impermanence.nix wipe-on-boot
{ ... }:
{
  disko.devices.disk.main = {
    type = "disk";
    # by-id node, not /dev/nvme0n1 (enum order unstable, --mode destroy wipes wrong disk)
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
