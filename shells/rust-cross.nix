# cross-rust devshell for the aarch64 packing pipeline (phosphene): a host-x86
# box that produces AND runs aarch64 output. lifted out of flake.nix like
# shells/pwn.nix to keep the top-level thin.
#
# the toolchain comes from rust-overlay (oxalica), NOT bare nixpkgs.rustc:
# nixpkgs ships only host rustc/cargo, no clippy/rust-src and no cross std. one
# overlaid toolchain carries every piece at a single matched version.
#
# two tiers, selected by withLlvm:
#   - default (false): the essential seam. cross rustc + lld + qemu + file/ffmpeg
#     verification, plus a few cheap tools for the §12 fuzz mandate and the M2
#     differential corpus. lean closure.
#   - true: adds LLVM/clang 18 dev libs + LLVM_SYS_180_PREFIX so the llvm-sys /
#     inkwell crates can build a real clang plugin (M1). a real chunk of closure
#     size, so it is a separate opt-in shell (nix develop .#rust-cross-llvm).
#
# cross linking is lld-only by design: the M2 PIE stub and the freestanding
# aarch64-unknown-none runtime link without a cross gcc (no_std / static crt).
# if a glibc crt ever shows up, add pkgsCross.aarch64-multiplatform.buildPackages
# gcc here rather than reaching for a full cross toolchain by hand.
{
  pkgs,
  rust-overlay,
  withLlvm ? false,
}:
let
  rpkgs = pkgs.extend rust-overlay.overlays.default;

  toolchain = rpkgs.rust-bin.stable.latest.default.override {
    extensions = [
      "clippy"
      "rustfmt"
      "rust-src"
    ];
    targets = [
      "aarch64-unknown-linux-gnu" # the M2 ELF stub
      "aarch64-unknown-none" # the freestanding no_std runtime
    ];
  };

  # llvm 18 to match the version the llvm-sys/inkwell crates probe for
  # (LLVM_SYS_180_PREFIX). pinned so lld and the plugin libs never drift apart.
  llvm = pkgs.llvmPackages_18;

  essential = [
    toolchain
    llvm.lld # cross linker for the aarch64 PIE stub
    pkgs.qemu # run the aarch64 output on this x86 box
    pkgs.file # libmagic: confirm the WOOF magic + tools/magic entry fire
    pkgs.ffmpeg # ffprobe: prove the woofer WAV reads as audio
  ];

  # cheap, and each one earns its place: the §12 fuzz mandate + the M2
  # pack-me-vs-run-me differential corpus (real binaries traced under strace).
  niceToHave = with pkgs; [
    cargo-fuzz # fuzz the loader + woofer decoder (wants a nightly rust to run)
    flac # flac-encoded woofer input, alternative to WAV
    netpbm # pnmtopng: view/convert the spectro PPM output
    ripgrep
    coreutils
    sqlite
    zlib
  ];

  llvmKit = pkgs.lib.optionals withLlvm [
    llvm.llvm.dev
    llvm.clang
    llvm.libclang
  ];

  # qemu-aarch64 user-mode: run the packed binary directly on x86 linux. gated
  # off darwin, where user-mode emulation is not the same path.
  linuxExtras = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
    pkgs.qemu-user
  ];
in
pkgs.mkShell (
  {
    name = if withLlvm then "rust-cross-llvm" else "rust-cross";
    packages = essential ++ niceToHave ++ llvmKit ++ linuxExtras;

    shellHook = ''
      printf '\033[38;5;183mrust-cross%s ready\033[0m\n' '${pkgs.lib.optionalString withLlvm " +llvm18"}'
    '';
  }
  # only set the crate-probe var in the llvm tier so the lean shell carries no
  # dangling env pointing at a store path it never pulled in.
  // pkgs.lib.optionalAttrs withLlvm {
    LLVM_SYS_180_PREFIX = "${llvm.llvm.dev}";
  }
)
