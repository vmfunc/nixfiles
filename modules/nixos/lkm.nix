# out-of-tree kernel module dev, gated behind rice.lkm.enable (default off).
# the toolchain for building/checking an OOT LKM against the running kernel by
# hand (make/gcc/sparse + kbuild deps), plus KDIR pointed at this host's
# kernel.dev so `make -C $KDIR M=$PWD` finds headers without the FHS
# /lib/modules/$(uname -r)/build symlink NixOS never creates.
#
# WHY a shell KDIR and not the repo's flake devShell: phosphene's flake pins
# linuxPackages_6_6, but tuna runs linuxPackages_testing (7.2-rc). building
# against 6.6 loads fine nowhere here, the vermagic misses. this exports the
# _running_ kernel's tree so `just build && just load` matches uname -r.
#
# scope: this is the by-hand path (a repo checkout with its own Makefile, e.g.
# ~/workspace/phosphene). the packaged LKMs (inputs.kmods -> wired*) still build
# in their own nix derivations against kernel.moduleBuildDependencies and ignore
# this entirely.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.lkm;
  kernel = config.boot.kernelPackages.kernel;
in
{
  options.rice.lkm.enable = lib.mkEnableOption "out-of-tree kernel module build toolchain (make/gcc/sparse) + KDIR";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      gnumake
      gcc
      sparse # C=2 semantic checker (just sparse / just ci)
      bc
      bison
      flex
      elfutils # libelf for modpost
      openssl # kbuild crypto / module signing
      pahole # DEBUG_INFO_BTF pass, and this kernel builds BTF
      cpio
      qemu # `just vm`; `just demo` is self-contained via nix run .#vm
      # imagemagick (just shot/render) already ships via the emacs module.
    ];

    # kbuild reads KDIR; phosphene's Makefile does KDIR ?= /lib/modules/.../build,
    # which is absent on NixOS, so hand it the store path for the running kernel.
    # applies on next login (session var), or export it once in the current shell.
    environment.sessionVariables.KDIR = "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
  };
}
