#!/usr/bin/env python3
"""pwntools solve skeleton

usage:
    python solve.py            # local, no gdb
    python solve.py GDB        # local under gdb (needs a real gdb; linux/VM)
    python solve.py REMOTE     # remote target (set HOST/PORT below)
    python solve.py DEBUG      # verbose pwntools logging
"""

from pwn import *  # noqa: F401,F403

BINARY = "./bin/chall"
LIBC = "./bin/libc.so.6"  # set to None if not provided
HOST = "localhost"
PORT = 1337

context.binary = exe = ELF(BINARY, checksec=False)
context.terminal = ["tmux", "splitw", "-h"]
context.log_level = "debug" if args.DEBUG else "info"

libc = ELF(LIBC, checksec=False) if LIBC and os.path.exists(LIBC) else None


GDB_SCRIPT = """
break main
continue
"""


def start():
    if args.REMOTE:
        return remote(HOST, PORT)

    if args.GDB:
        # gdb.attach can't drive a linux ELF from a mach-o host; degrade to local
        if which("gdb") is None:
            log.warning("no gdb on PATH — running local without a debugger")
            return process([exe.path])
        return gdb.debug([exe.path], gdbscript=GDB_SCRIPT)

    return process([exe.path])


io = start()

s = io.send
sl = io.sendline
sa = io.sendafter
sla = io.sendlineafter
r = io.recv
rl = io.recvline
ru = io.recvuntil
rxu = io.recvuntil
cl = io.clean
ia = io.interactive


def logleak(name, val):
    log.success(f"{name}: {val:#x}")


def exploit():
    # ru(b"> ")
    # payload = flat({ exe.bss(): b"...", })
    # sl(payload)
    ia()


if __name__ == "__main__":
    exploit()
