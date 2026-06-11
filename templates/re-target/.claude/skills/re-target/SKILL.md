---
name: re-target
description: Per-target RE scaffold stub. Use when starting a fresh reverse-engineering effort against ONE binary/dylib/firmware image in this project dir. This is a thin local entry point — it sets up the case/ directory and hands off to the global /aarch64-triage methodology (static) and /firmware-diff (n-day) / /pwn (exploitation) skills. Fill in the target specifics below as you learn them.
---

# re-target

Local scaffold for a single RE target. The real methodology lives in the global
skills; this stub pins the case directory and the target facts so a context
reset can recover. **Re-read this file and `case/notes/findings.md` when resuming.**

## Target facts (fill in)

- **What:** <path / name of the binary, dylib, kernelcache, firmware image>
- **Arch:** <arm64 | arm64e (PAC live) | x86-64 | …>
- **Format:** <Mach-O exec | dylib | ELF | raw firmware | kernelcache>
- **Goal:** <triage | find-the-bug | n-day diff | full exploit | just understand X>
- **Mitigations:** <fill after `rabin2 -I` — PAC/BTI/CFI/XOM/NX/canary/PIE>

## 0. Case directory (do this first)

```
mkdir -p case/{notes,decomp,scripts,artifacts}
```

Every confirmed fact → `case/notes/findings.md` (address → meaning). Cleaned
decompilation → `case/decomp/<func>.c`. Scripts → `case/scripts/`.

## 1. Hand off to the right global skill

- **Static teardown** → invoke `/aarch64-triage`. Recon, mitigation reality
  check, surface mapping, two-decompiler cross-check. Default.
- **Patch-diff / n-day** (two versions of the same target) → `/firmware-diff`.
- **Exploitation** (have a bug, want a primitive→chain→solve) → `/pwn`, and use
  the `pwn` template's devShell for pwntools/angr/pwndbg.
- **Kernel/hypervisor target** → `/kernel-exploit`.

## Tooling in this shell

`nix develop` (or direnv auto-load) gives you radare2/rizin/cutter/ghidra,
binwalk, one_gadget, patchelf. The **r2mcp** and **pyghidra-mcp** servers are on
the host PATH, so Claude can drive r2/Ghidra directly. LLDB native for dynamic
arm64e (no VM for Mach-O). See `CLAUDE.md` in this dir.

## Guardrails

- Never `chmod +x` / execute an untrusted sample on the host. Static + emulate.
- The binary lies; the decompiler guesses. Verify every offset before you trust it.
