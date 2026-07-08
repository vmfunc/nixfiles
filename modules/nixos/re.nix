# reverse-engineering + exploit-dev desktop toolkit for the linux hosts. this is
# the GUI/debug layer the cross-platform home/profiles/security.nix (pentest/recon
# CLIs) does not carry, plus the linux-only tools the macs can't run (burpsuite,
# the custom RE-MCP pkgs that needed the additions overlay un-gated). system-level
# so they get PATH + .desktop entries. tuna is a kernel/RE box, so load it up.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # disassemblers / decompilers
    ghidra
    rizin
    cutter # rizin gui
    # radare2 already comes from security.nix

    # debugging. pwndbg was dropped from this nixpkgs pin (no top-level attr), so
    # gef is the gdb exploit-dev frontend here; re-add pwndbg if it returns.
    gdb
    gef

    # dynamic instrumentation
    frida-tools

    # exploitation kit (python)
    (python3.withPackages (
      ps: with ps; [
        pwntools
        capstone
        unicorn
        ropgadget
        ropper # only ships as a python3Packages attr in this pin, not top-level
      ]
    ))
    one_gadget

    # binary / hex
    imhex # gui hex editor + pattern language
    hexyl # cli hex
    binwalk # (also in security.nix; harmless dup, lists merge)

    # web / network cyber gui (linux-only; the macs use native apps)
    burpsuite
    wireshark # gui, alongside the cli in security.nix

    # azzie's custom RE-MCP toolchain. still pinned meta.platforms = darwin-only in
    # their pkgs/*/package.nix, so they REFUSE to eval on x86_64-linux (tuna) and
    # take the whole system closure down with them. left commented until each pkg
    # de-gates x86_64-linux upstream in pkgs/. TODO(deploy): once pkgs/<name>/
    # package.nix lists x86_64-linux (they were only ever exercised on darwin),
    # un-comment the ones that actually build here.
    # frida-mcp
    # r2mcp
    # binja-mcp
    # pyghidra-mcp
    # ghidrecomp
    # re-harness
  ];
}
