# re-target: project CLAUDE.md

Per-target reverse-engineering project. This file seeds the right context so a
fresh Claude session opens from azzie's RE mental model, not generic x86 triage.

## What this is

A single-target static RE scaffold. One binary / dylib / kernelcache / firmware
image gets torn down here. The methodology is externalized into the global skills
(`/aarch64-triage`, `/firmware-diff`, `/pwn`, `/kernel-exploit`). Start by reading
`.claude/skills/re-target/SKILL.md` for the local handoff, then invoke the global
skill that matches the goal.

## Read first

- **`~/.config/claude/asm-guide.md`**: aarch64/x86 asm conventions.
- **`~/.config/claude/security-guide.md`**: threat-model framing, CVSS rules
  (AV:N vs AV:A, PR:N vs PR:L), disclosure discipline.
- **`.claude/skills/re-target/SKILL.md`**: this target's facts + the handoff.

## Working assumptions

- **arm64e ⇒ PAC/BTI/CFI/XOM live** (Apple firmware since 21.0.0). Note the PAC
  signing context per site; a signed pointer reused under a different context is
  the bug. XPACI/XPACD strip without auth.
- Mach-O triage is **native**: `rabin2 -I`, `otool`, `codesign`, LLDB. Do NOT
  use `checksec.sh` on Mach-O (ELF-only, lies). No Linux VM for Mach-O dynamic.
- Don't trust tool output blindly. Cross-check two decompilers on anything
  load-bearing. Verify every offset in a debugger before relying on it.

## Tooling

- Shell: `nix develop` / direnv → radare2, rizin, cutter, ghidra, binwalk,
  one_gadget, patchelf. (`pwn` template's shell for pwntools/angr/pwndbg.)
- **MCP**: `r2mcp` and `pyghidra-mcp` are on the host PATH, drive r2 / Ghidra
  directly instead of shelling out and parsing text.
- `case/{notes,decomp,scripts,artifacts}/` is working memory, write confirmed
  facts to `case/notes/findings.md` and re-read it on resume.

## Guardrails

- Never execute an untrusted sample on the host. Static + emulate (r2 ESIL).
  Detonate only in an isolated Linux-ELF cage, never for Mach-O.
- Assume hostile input. The binary lies. Verify.
