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

    # debugging
    gdb
    pwndbg # gdb + the exploit-dev plugin
    gef # second gdb frontend, both on PATH

    # dynamic instrumentation
    frida-tools

    # exploitation kit (python)
    (python3.withPackages (
      ps: with ps; [
        pwntools
        capstone
        unicorn
        ropgadget
      ]
    ))
    ropper
    one_gadget

    # binary / hex
    imhex # gui hex editor + pattern language
    hexyl # cli hex
    binwalk # (also in security.nix; harmless dup, lists merge)

    # web / network cyber gui (linux-only; the macs use native apps)
    burpsuite
    wireshark # gui, alongside the cli in security.nix

    # azzie's custom RE-MCP toolchain, now buildable on linux (additions overlay
    # is no longer darwin-gated). TODO(deploy): drop any that fail to build on the
    # first rebuild and file them; they were only ever exercised on darwin.
    frida-mcp
    r2mcp
    binja-mcp
    pyghidra-mcp
    ghidrecomp
    re-harness
  ];
}
