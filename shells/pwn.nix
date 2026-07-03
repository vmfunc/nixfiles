# pwn/ctf devshell, lifted out of flake.nix to keep the top-level thin.
# mirrors templates/pwn minus the pwndbg flake input (use the template on linux).
# darwin gets pwntools + native re; linux adds the gdb/gef/seccomp kit.
{ pkgs }:
let
  py = pkgs.python3.withPackages (
    ps: with ps; [
      pwntools
      ropper
      ropgadget
      angr
      angrop
      capstone
      unicorn
      keystone-engine
      requests
      ipython
    ]
  );
  coreNative =
    (with pkgs; [
      radare2
      rizin
      cutter
      ghidra
      binwalk
      one_gadget
      patchelf
      file
      ripgrep
      qemu
      lima
      colima
      pkgsCross.aarch64-multiplatform.buildPackages.gdb
    ])
    # ctf-new only lands in `packages` on darwin; callPackage it so linux still evaluates
    ++ [ (pkgs.callPackage ../pkgs/ctf-new/package.nix { }) ];
  linuxExtras = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux (
    with pkgs;
    [
      gdb
      gef
      qemu-user
      checksec
      pwninit
      elfutils
      rubyPackages.seccomp-tools
    ]
  );
in
pkgs.mkShell {
  name = "pwn";
  packages = [ py ] ++ coreNative ++ linuxExtras;
  shellHook = ''
    printf '\033[38;5;183mpwn shell ready\033[0m\n'
  '';
}
