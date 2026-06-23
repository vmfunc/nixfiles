# cuttlefish: Framework Laptop 12 provisioning runbook

Declarative FDE (disko: GPT + ESP + LUKS2 + btrfs subvols) · impermanence
(wipe-`@`-on-boot) · framework-12-13th-gen-intel hardware · lanzaboote Secure
Boot + TPM2 LUKS auto-unlock. The config **evaluates clean on the Mac**; it
can't be hardware-tested until the Framework exists. Build *on the Framework*,
never via emulation on otter (the x86_64 closure needs a real x86_64 builder).

## the two things that will brick/lock you out if skipped

Both must be done **after install, before the first reboot into the wiped fs:**

1. **Set a password.** `mutableUsers = true` + wipe-on-boot means an imperative
   `passwd` lands on subvol `@` and is **erased every boot** → no console login.
   Fix one of: set `users.users.quaver.initialHashedPassword` (`mkpasswd -m yescrypt`),
   persist `/etc/shadow`, or finish the commented sops user-password path in
   `modules/nixos/impermanence.nix`.
2. **Create the `@blank` snapshot.** The initrd rollback restores from
   `/mnt/@blank`, but disko only makes `@`. Without it the rollback service
   **fails on first boot**. Mount the btrfs top-level (`subvolid=5`) and:
   `btrfs subvolume snapshot -r /mnt/@ /mnt/@blank` (or add a disko `postCreateHook`).

## steps

0. **Replace the disk placeholder.** In `hosts/cuttlefish/disko.nix`, set
   `device =` to the real `/dev/disk/by-id/nvme-<model>_<serial>` (from
   `ls -l /dev/disk/by-id` on the live ISO, **never** a `-partN` or `/dev/nvme0n1`).
   Stage it (flake ignores untracked files).

1. **Build + install from the Mac** (builds remotely on the Framework, otter
   can't realize the x86_64 closure):
   ```
   nix run github:nix-community/nixos-anywhere -- \
     --flake .#cuttlefish --target-host root@<framework-ip> --build-on remote \
     --generate-hardware-config nixos-generate-config ./hosts/cuttlefish/hardware.nix
   ```
   (Boot the Framework off the NixOS minimal ISO first; enable sshd + a root
   password on the live env.) disko **destroys the disk**, sets the LUKS passphrase.

2. **→ do the two pre-reboot must-dos above ←**, then reboot. First boot runs
   with Secure Boot off (self-keys not enrolled yet); LUKS prompts the passphrase.
   Confirm console login works + no rollback-service failure in the journal.

3. **Secure Boot (sbctl):** on the box:
   ```
   sbctl create-keys
   nixos-rebuild switch --flake .#cuttlefish      # signs the UKI
   # reboot → firmware → Secure Boot into Setup Mode
   sbctl enroll-keys --microsoft                # --microsoft is MANDATORY on Framework
   # re-enable Secure Boot, boot
   bootctl status                               # → Secure Boot: enabled (user)
   ```
   (`/var/lib/sbctl` is persisted, so keys survive the wipe.)

4. **TPM2 auto-unlock** (only after SB is verified stable):
   ```
   systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto \
     --tpm2-pcrs=0+2+7 --tpm2-with-pin=yes /dev/disk/by-uuid/<LUKS-UUID>
   ```
   **Keep the LUKS passphrase forever**, it's the recovery slot, and firmware
   updates change PCR0/2 and force a TPM re-enroll. `--tpm2-with-pin=yes` is the
   minimum mitigation for the known initrd-spoof TPM-unlock bypass.

5. **Ongoing deploys** (needs `services.openssh.enable`):
   ```
   nixos-rebuild switch --flake .#cuttlefish \
     --target-host quaver@cuttlefish --build-host quaver@cuttlefish --use-remote-sudo
   ```

6. Re-run `nixos-generate-config --no-filesystems` on real hardware to capture
   the true `availableKernelModules` into `hardware.nix`, and commit.

## notes
- `allowDiscards = true` on LUKS leaks a rough used-space fingerprint at rest
  (accepted tradeoff for a daily driver; matters only if imaged while powered off).
- No suspend-to-disk wired (`resumeDevice` empty), the 16G encrypted swap is
  memory-pressure only.
- Minor lock hygiene: nixos-hardware + impermanence each pull a separate
  transitive nixpkgs; harmless, optionally add `inputs.nixpkgs.follows = "nixpkgs"`
  to both to shrink the lock.
