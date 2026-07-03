{ ... }:
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

      # wipe everything under @, then @ itself. cut -f9- not -f9: the path field
      # runs to end of line, -f9 truncates a path containing a space. plain list
      # + grep '^@/' sees grandchildren (nspawn/portables state) that -o hides,
      # and sort -r puts children before parents so leaves delete first. bounded
      # retries, then a loud check: a leftover subvol must fail the unit instead
      # of letting the box boot un-wiped.
      for _pass in 1 2 3; do
        subs=$(btrfs subvolume list /mnt | cut -f9- -d' ' | grep '^@/' | sort -r || true)
        [ -z "$subs" ] && break
        printf '%s\n' "$subs" | while read -r sub; do
          btrfs subvolume delete "/mnt/$sub" || true
        done
      done
      [ -z "$(btrfs subvolume list /mnt | cut -f9- -d' ' | grep '^@/' || true)" ]
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
      "/etc/NetworkManager/system-connections"
      "/var/lib/NetworkManager"
      "/var/lib/bluetooth"
      "/var/lib/sbctl" # lanzaboote/secureboot pki
      "/var/lib/tailscale" # node key; a wiped one mints a new tailnet identity every boot
      "/var/lib/upower"
    ];

    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
    ];

    # no users.<name> block on purpose: /home is its own @home subvolume the
    # rollback never touches, so all of home already survives every boot.
    # bind-mounting dirs from /persist would only split user state across two
    # subvolumes.
  };

  # sops-gated user password, locks you out if enabled before the secret exists
  # (PROVISIONING.md must-do #1). the recipe below does NOT eval today; the
  # exact missing pieces, in order:
  #   1. import inputs.sops-nix.nixosModules.sops in mkNixos (lib/default.nix);
  #      only the home-manager sops module is wired in, so the system-level
  #      sops.* option tree does not exist yet.
  #   2. add `config` and `username` back to this module's args.
  #   3. add the host-key age recipient (ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub)
  #      to the repo .sops.yaml and create secrets/cuttlefish.yaml holding
  #      `user-password` (mkpasswd -m yescrypt). never key this off the homedir
  #      age key: neededForUsers decrypts before /home is up, so the first wiped
  #      boot would brick console login. the host key files are persisted above,
  #      which also means no /var/lib/sops-nix state is ever needed.
  #   4. uncomment, switch, and verify console login BEFORE rebooting into the
  #      wiped fs.
  #
  # users.mutableUsers = false;
  # sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  # sops.secrets."user-password" = {
  #   sopsFile = ../../secrets/cuttlefish.yaml;
  #   neededForUsers = true;
  # };
  # users.users.${username}.hashedPasswordFile =
  #   config.sops.secrets."user-password".path;
}
