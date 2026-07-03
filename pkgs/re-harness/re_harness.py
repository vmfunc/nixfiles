#!/usr/bin/env python3
# headless claude agent sdk batch RE triage runner.
# one agent query() per binary in a corpus, /aarch64-triage SKILL.md as system
# prompt, r2mcp as the analysis engine; surfaces binaries that cleared a finding.

from __future__ import annotations

import argparse
import asyncio
import os
import signal
import sys
from dataclasses import dataclass, field
from pathlib import Path

from claude_agent_sdk import (
    AssistantMessage,
    ClaudeAgentOptions,
    ResultMessage,
    SystemMessage,
    TextBlock,
    query,
)

# ansi 256-color accents (shared with the other cozy CLIs)
_MAUVE = "\033[38;5;183m"
_SUBTEXT = "\033[38;5;146m"
_GREEN = "\033[38;5;151m"
_RED = "\033[38;5;210m"
_RESET = "\033[0m"


def _supports_color() -> bool:
    return sys.stderr.isatty() and os.environ.get("NO_COLOR") is None


def _c(color: str, text: str) -> str:
    return f"{color}{text}{_RESET}" if _supports_color() else text


# turn cap is a runaway/cost backstop; RE plateaus well before this
_MAX_TURNS_PER_BINARY = 40

_FINDINGS_REL = Path("notes") / "findings.md"

_CASE_SUBDIRS = ("notes", "decomp", "scripts", "artifacts")

_SKIP_NAMES = frozenset({".DS_Store", ".gitkeep", ".gitignore"})

# more content lines than the empty scaffold == cleared a finding
_MIN_FINDING_LINES = 3

_R2MCP_SERVER = "r2mcp"

# headless: no human to approve mid-run, so anything not listed gets denied and stalls
_AUTO_ALLOWED_TOOLS = (
    f"mcp__{_R2MCP_SERVER}",
    "Read",
    "Grep",
    "Glob",
    "Write",
    "Edit",
)

# never allow bash: it's the one host tool that could detonate the sample. recon goes through r2mcp.
_DENIED_TOOLS = ("Bash",)


_DEFAULT_SKILL_PATH = Path(__file__).with_name("SKILL.md")


@dataclass
class BinaryResult:
    """Outcome of triaging one binary."""

    name: str
    case_dir: Path
    ok: bool = False
    error: str | None = None
    findings_lines: int = 0
    summary: str = ""
    text_chunks: list[str] = field(default_factory=list)

    @property
    def cleared(self) -> bool:
        return self.ok and self.findings_lines >= _MIN_FINDING_LINES


def _load_skill(skill_path: Path) -> str:
    try:
        return skill_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise SystemExit(
            _c(_RED, f"re-harness: cannot read skill prompt at {skill_path}: {exc}")
        ) from exc


def _build_system_prompt(skill_text: str) -> str:
    return (
        "You are a headless reverse-engineering triage agent operating in a "
        "batch harness. You are handed ONE binary at a time. Your working "
        "directory is a dedicated case/ directory for this binary.\n\n"
        "Operating contract:\n"
        "  - Follow the AArch64 triage methodology below.\n"
        "  - Use the r2mcp MCP server for static analysis (radare2). It is "
        "already wired in.\n"
        "  - NEVER execute, run, or detonate the target. Static + emulation "
        "only. r2's `!` shell-escape is OFF-LIMITS for the sample. If dynamic "
        "analysis is needed, STOP and say so. Detonation happens in an "
        "isolated VM, not here.\n"
        "  - Write every CONFIRMED fact (address -> meaning, mitigations, "
        "bug class + primitive) to notes/findings.md as you go. Only confirmed "
        "facts, mark anything unverified as UNVERIFIED.\n"
        "  - Stop at a plateau: when further static triage yields no new "
        "confirmed facts, write a one-line SUMMARY: at the top of "
        "notes/findings.md and finish. Do not spin.\n"
        "  - If the binary is benign/uninteresting after recon, say so plainly "
        "and stop, don't manufacture findings.\n\n"
        "=== /aarch64-triage skill ===\n" + skill_text
    )


def _scaffold_case(case_root: Path, name: str) -> Path:
    case_dir = case_root / name
    for sub in _CASE_SUBDIRS:
        (case_dir / sub).mkdir(parents=True, exist_ok=True)
    return case_dir


def _count_findings_lines(findings: Path) -> int:
    # substantive lines only: non-blank, non-heading, non-template-placeholder
    try:
        raw = findings.read_text(encoding="utf-8")
    except OSError:
        return 0
    count = 0
    for line in raw.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("#"):
            continue
        if stripped.endswith(":"):
            continue
        if stripped.startswith("- [ ]"):
            continue
        count += 1
    return count


def _mcp_servers() -> dict:
    return {
        _R2MCP_SERVER: {
            "type": "stdio",
            "command": _R2MCP_SERVER,
            "args": [],
        }
    }


def _options(
    case_dir: Path,
    sample_dir: Path,
    system_prompt: str,
    mcp_servers: dict,
) -> ClaudeAgentOptions:
    return ClaudeAgentOptions(
        cwd=str(case_dir),
        system_prompt=system_prompt,
        mcp_servers=mcp_servers,
        # don't inherit project/user .mcp.json, keep batch runs reproducible
        strict_mcp_config=True,
        permission_mode="acceptEdits",
        allowed_tools=list(_AUTO_ALLOWED_TOOLS),
        disallowed_tools=list(_DENIED_TOOLS),
        # sample lives outside the cwd; grant its dir read-only, never copy it
        add_dirs=[str(sample_dir)],
        max_turns=_MAX_TURNS_PER_BINARY,
    )


def _prompt_for(binary: Path) -> str:
    return (
        f"Triage the binary at: {binary}\n\n"
        "Set up the case directory (notes/ decomp/ scripts/ artifacts/ already "
        "exist here), run recon, do the mitigation reality check, map the "
        "surface, and record every confirmed fact in notes/findings.md. "
        "Stop at a plateau and write a SUMMARY: line. Do NOT run the binary."
    )


async def _triage_one(binary: Path, case_dir: Path, options: ClaudeAgentOptions) -> BinaryResult:
    result = BinaryResult(name=binary.name, case_dir=case_dir)
    try:
        async for message in query(prompt=_prompt_for(binary), options=options):
            if isinstance(message, AssistantMessage):
                for block in message.content:
                    if isinstance(block, TextBlock) and block.text.strip():
                        result.text_chunks.append(block.text.strip())
            elif isinstance(message, ResultMessage):
                if message.is_error:
                    status = (
                        f" (http {message.api_error_status})"
                        if message.api_error_status
                        else ""
                    )
                    result.error = (message.result or message.subtype or "agent error") + status
                else:
                    result.ok = True
                    if message.result:
                        result.summary = message.result.strip()
            elif isinstance(message, SystemMessage):
                pass
    except asyncio.CancelledError:
        result.error = "cancelled"
        raise
    except Exception as exc:  # noqa: BLE001, one bad binary must not kill the batch
        result.ok = False
        result.error = f"{type(exc).__name__}: {exc}"

    result.findings_lines = _count_findings_lines(case_dir / _FINDINGS_REL)
    if not result.summary and result.text_chunks:
        result.summary = result.text_chunks[-1].splitlines()[-1].strip()
    return result


def _iter_corpus(corpus: Path) -> list[Path]:
    # flat, non-recursive, don't sweep up case/ output from a previous run
    targets: list[Path] = []
    for entry in sorted(corpus.iterdir()):
        if entry.name in _SKIP_NAMES:
            continue
        if entry.is_file() and not entry.is_symlink():
            targets.append(entry)
    return targets


def _print_banner(corpus: Path, count: int, case_root: Path) -> None:
    print(_c(_MAUVE, "re-harness: batch AArch64 triage"), file=sys.stderr)
    print(
        _c(_SUBTEXT, f"   corpus: {corpus}  ·  {count} target(s)  ·  cases -> {case_root}"),
        file=sys.stderr,
    )
    print(
        _c(
            _RED,
            "   GUARDRAIL: static/emulation only. Detonate untrusted samples in the "
            "#pwn colima/lima VM, never on the host (r2mcp `!` shell-escapes).",
        ),
        file=sys.stderr,
    )
    print(file=sys.stderr)


def _print_progress(index: int, total: int, result: BinaryResult) -> None:
    head = _c(_MAUVE, f"[{index}/{total}]")
    name = _c(_GREEN, result.name)
    if result.error:
        status = _c(_RED, f"error: {result.error}")
    elif result.cleared:
        status = _c(_GREEN, f"finding ({result.findings_lines} lines)")
    else:
        status = _c(_SUBTEXT, "no finding")
    line = f"{head} {name}: {status}"
    if result.summary and not result.error:
        snippet = result.summary.replace("\n", " ")
        if len(snippet) > 80:
            snippet = snippet[:77] + "..."
        line += _c(_SUBTEXT, f"  {snippet}")
    print(line, file=sys.stderr)


def _print_report(results: list[BinaryResult]) -> None:
    cleared = [r for r in results if r.cleared]
    errored = [r for r in results if r.error]
    print(file=sys.stderr)
    print(_c(_MAUVE, "── summary ──────────────────────────────"), file=sys.stderr)
    print(
        _c(
            _SUBTEXT,
            f"   {len(results)} triaged  ·  {len(cleared)} with findings  ·  "
            f"{len(errored)} errored",
        ),
        file=sys.stderr,
    )
    if cleared:
        print(_c(_GREEN, "   cleared a finding:"), file=sys.stderr)
        for r in cleared:
            print(
                _c(_GREEN, f"     • {r.name}")
                + _c(_SUBTEXT, f"  -> {r.case_dir / _FINDINGS_REL}"),
                file=sys.stderr,
            )
    # stdout: one findings path per line, pipeline-friendly
    for r in cleared:
        print(str(r.case_dir / _FINDINGS_REL))


async def _run(args: argparse.Namespace) -> int:
    corpus = Path(args.corpus).expanduser().resolve()
    if not corpus.is_dir():
        print(_c(_RED, f"re-harness: not a directory: {corpus}"), file=sys.stderr)
        return 2

    case_root = (
        Path(args.case_root).expanduser().resolve()
        if args.case_root
        else corpus / "cases"
    )
    case_root.mkdir(parents=True, exist_ok=True)

    skill_text = _load_skill(Path(args.skill).expanduser() if args.skill else _DEFAULT_SKILL_PATH)
    system_prompt = _build_system_prompt(skill_text)
    mcp_servers = _mcp_servers()

    targets = _iter_corpus(corpus)
    if not targets:
        print(_c(_SUBTEXT, f"re-harness: no target files under {corpus}"), file=sys.stderr)
        return 0

    _print_banner(corpus, len(targets), case_root)

    results: list[BinaryResult] = []
    total = len(targets)
    for index, binary in enumerate(targets, start=1):
        case_dir = _scaffold_case(case_root, binary.name)
        options = _options(case_dir, binary.parent, system_prompt, mcp_servers)
        result = await _triage_one(binary, case_dir, options)
        results.append(result)
        _print_progress(index, total, result)

    _print_report(results)
    # non-zero only if every binary errored (likely missing claude CLI / API key)
    if results and all(r.error for r in results):
        return 1
    return 0


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="re-harness",
        description=(
            "Headless Claude Agent SDK batch RE triage runner. "
            "One agent per binary in <corpus-dir>; each triages with the "
            "/aarch64-triage methodology + r2mcp, writes confirmed facts to a "
            "per-binary case/notes/findings.md, and stops at a plateau. Only "
            "binaries that cleared a finding are surfaced (paths on stdout)."
        ),
        epilog=(
            "GUARDRAIL: this harness performs STATIC/emulated triage only and "
            "never executes a target. r2mcp can shell-escape (`!cmd` inside "
            "r2), so run untrusted samples through the #pwn colima/lima VM, "
            "never bare on the host. Requires the `claude` CLI on PATH and a "
            "configured API key / auth."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("corpus", help="directory of binaries to triage (flat, non-recursive)")
    parser.add_argument(
        "--case-root",
        default=None,
        help="where per-binary case/ dirs are written (default: <corpus>/cases)",
    )
    parser.add_argument(
        "--skill",
        default=None,
        help="override the system-prompt skill file (default: baked-in /aarch64-triage SKILL.md)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(sys.argv[1:] if argv is None else argv)
    try:
        return asyncio.run(_run(args))
    except KeyboardInterrupt:
        print(_c(_RED, "\nre-harness: interrupted"), file=sys.stderr)
        return 130


if __name__ == "__main__":
    # default SIGPIPE so `re-harness | head` doesn't dump a BrokenPipe trace
    try:
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    except (AttributeError, ValueError):
        pass
    sys.exit(main())
