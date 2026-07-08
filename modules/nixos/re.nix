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

    # azzie's custom RE-MCP toolchain. meta.platforms now lists x86_64-linux in each
    # pkgs/<name>/package.nix and all five below build clean on tuna (frida/radare2/
    # ghidra are cross-platform). binja-mcp stays OFF this list: its bridge is portable
    # but useless without the commercial Binary Ninja darwin .app, so it is pinned
    # darwin-only in pkgs/binja-mcp/package.nix and lives on the macs only.
    frida-mcp
    r2mcp
    pyghidra-mcp
    ghidrecomp
    re-harness
  ];
}
