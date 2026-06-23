{
  username,
  ...
}:
let
  luksName = "cryptroot";
in
{
  # after LUKS opens, before / mounts; needs boot.initrd.systemd.enable
  boot.initrd.systemd.services.rollback = {
    description = "Rollback btrfs root subvolume to a pristine state";
    wantedBy = [ "initrd.target" ];
    after = [ "systemd-cryptsetup@${luksName}.service" ];
    before = [ "sysroot.mount" ];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /mnt
      # mount the top level (subvolid=5), not subvol=@, can't delete the subvol you're on
      mount -o subvol=/ /dev/mapper/${luksName} /mnt

      btrfs subvolume list -o /mnt/@ | cut -f9 -d' ' | while read -r sub; do
        btrfs subvolume delete "/mnt/$sub"
      done
      btrfs subvolume delete /mnt/@

      btrfs subvolume snapshot /mnt/@blank /mnt/@

      umount /mnt
    '';
  };

  # disko mounts these but doesn't set neededForBoot; without it /persist lands in stage-2
  # after services read empty dirs (machine-id regen, lost wifi, missing age key)
  fileSystems."/persist".neededForBoot = true;
  fileSystems."/nix".neededForBoot = true;
  fileSystems."/home".neededForBoot = true;

  environment.persistence."/persist" = {
    enable = true;
    hideMounts = true;

    directories = [
      "/var/log"
      "/var/lib/nixos" # uid/gid allocation map
      "/var/lib/systemd"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"
      "/var/lib/NetworkManager"
      "/var/lib/bluetooth"
      "/var/lib/sbctl" # lanzaboote/secureboot pki
      "/var/lib/upower"

      {
        directory = "/var/lib/sops-nix";
        mode = "u=rwx,g=,o=";
      }
    ];

    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];

    users.${username} = {
      directories = [
        ".ssh"
        ".config/sops"
        ".local/share"
        ".local/state"
        ".config"
      ];
    };
  };

  # sops-gated, locks you out if enabled before the system password secret exists.
  # add a system sops file with `user-password` (mkpasswd -m yescrypt), uncomment,
  # then verify console login before rebooting into the wiped fs.
  #
  # users.mutableUsers = false;
  # sops.secrets."user-password".neededForUsers = true;
  # users.users.${username}.hashedPasswordFile =
  #   config.sops.secrets."user-password".path;
}
