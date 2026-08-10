# nix-ld: let generic (non-nix) dynamically-linked ELFs run on nixos. lots of
# prebuilt dev/RE tooling ships a linux-x64 binary built against /lib64/ld-linux,
# which nixos does not provide, so they die with "could not start dynamically
# linked executable" (the stub-ld message at nix.dev/permalink/stub-ld). concrete
# trigger: zed's claude agent runs @anthropic-ai/claude-agent-sdk-linux-x64/claude
# fetched via npx, exactly such a binary (exit 127). nix-ld installs a real loader
# at that path and exports NIX_LD + NIX_LD_LIBRARY_PATH from the libraries below.
#
# on unconditionally for every linux host: azzie runs prebuilt binaries constantly
# (RE tools, vendor SDKs), so this is base capability, not a per-host opt-in. the
# library list is the common closure (libstdc++/libgcc, zlib, openssl); extend it
# if a specific binary reports a missing .so at runtime.
{ pkgs, ... }:
{
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
  ];
}
