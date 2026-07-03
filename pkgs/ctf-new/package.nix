{
  writeShellApplication,
  git,
  coreutils,
}:
writeShellApplication {
  name = "ctf-new";

  runtimeInputs = [
    git
    coreutils
  ];

  text = ''
    set -euo pipefail

    mauve=$'\033[38;5;183m'
    subtext=$'\033[38;5;146m'
    green=$'\033[38;5;151m'
    reset=$'\033[0m'

    name="''${1:-}"
    if [ -z "$name" ]; then
      printf '%susage: ctf-new <challenge-name>%s\n' "$mauve" "$reset" >&2
      exit 1
    fi

    if [ -e "$name" ]; then
      printf '%s%s already exists, refusing to clobber.%s\n' "$mauve" "$name" "$reset" >&2
      exit 1
    fi

    root="$name/chall"
    mkdir -p "$root/bin" "$root/exploit" "$root/notes"

    cat > "$root/exploit/solve.py" <<'PYEOF'
    #!/usr/bin/env python3
    """pwntools solve skeleton

    usage:
        python solve.py            # local
        python solve.py GDB        # local under gdb (linux/VM)
        python solve.py REMOTE     # remote target
        python solve.py DEBUG      # verbose logging
    """

    from pwn import *  # noqa: F401,F403

    BINARY = "../bin/chall"
    LIBC = "../bin/libc.so.6"
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
            if which("gdb") is None:
                log.warning("no gdb on PATH, running local without a debugger")
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
    cl = io.clean
    ia = io.interactive


    def logleak(name, val):
        log.success(f"{name}: {val:#x}")


    def exploit():
        ia()


    if __name__ == "__main__":
        exploit()
    PYEOF

    cat > "$name/.envrc" <<'ENVEOF'
    # direnv auto-load. `direnv allow` once.
    # uses the pwn template flake if you `nix flake init -t <mac-rice>#pwn`,
    # otherwise point this at your shared pwn flake.
    use flake
    ENVEOF

    cat > "$root/notes/notes.md" <<NOTESEOF
    # $name

    ## target
    - host:port:
    - binary: chall
    - files given:

    ## arch / format
    - arch:            (x86_64 / aarch64 / ...)
    - bits:
    - endianness:
    - static / dynamic:
    - libc version:

    ## mitigations
    - [ ] RELRO        (none / partial / full)
    - [ ] Stack canary
    - [ ] NX
    - [ ] PIE
    - [ ] ASLR (remote)
    - [ ] seccomp      (dump with seccomp-tools)
    - [ ] PAC / BTI    (aarch64)

    ## surface / approach
    - bug:
    - primitive:
    - plan:

    ## flag checklist
    - [ ] local crash reproduced
    - [ ] leak obtained
    - [ ] control of PC / RIP
    - [ ] works locally
    - [ ] works remote
    - [ ] flag:
    NOTESEOF

    git init -q "$name"
    {
      echo '*.pyc'
      echo '__pycache__/'
      echo '.direnv/'
      echo 'core'
      echo 'flag.txt'
    } > "$name/.gitignore"
    git -C "$name" add -A
    git -C "$name" commit -qm "ctf-new: scaffold $name" >/dev/null 2>&1 || true

    chmod +x "$root/exploit/solve.py"

    printf '%snew challenge ready:%s %s%s%s\n' "$mauve" "$reset" "$green" "$name" "$reset"
    printf '%s   %s/%s\n' "$subtext" "$root" "$reset"
    printf '%s     bin/      drop the target + libc/ld here%s\n' "$subtext" "$reset"
    printf '%s     exploit/  solve.py (pwntools skeleton)%s\n' "$subtext" "$reset"
    printf '%s     notes/    notes.md (target / mitigations / flag checklist)%s\n' "$subtext" "$reset"
    printf '%s   next:%s cd %s && direnv allow%s\n' "$mauve" "$subtext" "$name" "$reset"
  '';

  meta = {
    description = "scaffold a ctf challenge dir (bin/exploit/notes + pwntools skeleton)";
    mainProgram = "ctf-new";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
