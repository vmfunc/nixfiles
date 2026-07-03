# aarch64-linux VM builder for the macs (builds linux derivations locally). x86_64 here would be
# qemu-user emulation (slow, miscompiles rust-std/go cgo); a real x86_64 host should build its own.
# for x86_64 also set config.boot.binfmt.emulatedSystems and nix.settings.extra-platforms
{ ... }:
{
  # ephemeral = false: persist the VM store so a boot failure doesn't
  # rebuild the 1.85 GB erofs image on every KeepAlive restart (was crash-
  # looping qemu under macOS 26.5.1 and thrashing the machine into swap).
  nix.linux-builder = {
    enable = true;
    ephemeral = false;
  };
}
