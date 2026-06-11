# aarch64-linux only; x86_64 here means qemu-user emulation (slow, miscompiles rust-std/go cgo) — build cuttlefish on the framework instead
# for x86_64 also set config.boot.binfmt.emulatedSystems and nix.settings.extra-platforms
{ ... }:
{
  nix.linux-builder = {
    enable = true;
    ephemeral = true;
  };
}
