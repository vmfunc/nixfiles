# pwn .gdbinit — mauve-ish, linux-aware.
# only meaningful where an ELF-capable gdb exists (the aarch64-linux VM / linux host);
# macos gdb is macho-only + codesign-gated.

set confirm off
set pagination off
set disassembly-flavor intel
set history save on
set history size 4096
set print pretty on
set print asm-demangle on

set prompt \001\033[38;5;183m\002pwn>\001\033[0m\002

set follow-fork-mode child
set detach-on-fork on

# pwndbg, if present
python
import os
for _cand in (
    os.path.expanduser("~/.pwndbg/gdbinit.py"),
    os.path.expanduser("~/pwndbg/gdbinit.py"),
    "/opt/pwndbg/gdbinit.py",
):
    if os.path.exists(_cand):
        gdb.execute(f"source {_cand}")
        break
end

# gef fallback:
# source ~/.gef-2026.01.py
