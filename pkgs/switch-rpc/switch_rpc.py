#!/usr/bin/env python3
"""switch-rpc: run a command with a Discord rich presence while it runs.

wraps `just switch` (see justfile): connects to the local Discord IPC socket
(Vesktop's bundled arRPC, same as nowplaying-rpc), sets a "rebuilding <host>"
activity with an elapsed timer, runs the wrapped command, and clears the
presence when it exits, propagating the command's exit code.

LIVE STATE: while the command runs, its output is scanned for nix's
"building '/nix/store/<hash>-<name>.drv'" markers and the presence state line
follows the most recent one ("building linux-6.16-rc2"). to keep nh's
interactive renderer working the child runs on a pty when stdout is a tty
(bytes pass through untouched; we only *observe* them); on a pipe (CI, logs)
it degrades to a plain pipe and parses the same markers from plain logs.

FAIL-OPEN, the deliberate opposite of nowplaying-rpc's fail-closed: there the
daemon IS the presence, so no client id means nothing to do. here the wrapped
command is a system rebuild and the presence is decoration, so ANY
Discord-side failure (no client id, no socket, handshake error) degrades to
running the command bare. a rebuild must never fail because Discord is down.

the client id is a public Discord application id (not a secret); it is baked
into the wrapper by pkgs/switch-rpc/package.nix from rice.switchRpc.clientId,
and SWITCH_RPC_CLIENT_ID in the environment still wins for ad-hoc testing. the
activity renders as "Playing <that application's name>" ("nixpkgs").
"""

from __future__ import annotations

import fcntl
import os
import pty
import re
import signal
import socket
import struct
import subprocess
import sys
import termios
import time

CLIENT_ID = os.environ.get("SWITCH_RPC_CLIENT_ID", "").strip()

# Discord art asset key on the application (azzie's "nixpkgs" app carries a
# "nix" asset). an unknown key renders imageless, never errors, so this needs
# no gating; override for a different asset or an https url (Discord proxies).
LARGE_IMAGE = os.environ.get("SWITCH_RPC_IMAGE", "nix").strip()

# Discord truncates presence fields at 128 chars; clamp ourselves first.
FIELD_MAX = 128

# floor between SET_ACTIVITY pushes (Discord allows ~5/20s); a burst of tiny
# drvs coalesces to the most recent name instead of tripping the limit.
MIN_UPDATE_INTERVAL_S = 4.0

# a build start in nix logs (plain or inside nh's ANSI stream): the .drv store
# path. group(1) is the human name ("linux-6.16-rc2"), hash stripped.
DRV_RE = re.compile(rb"/nix/store/[a-z0-9]{32}-([^/\s'\"]+?)\.drv")
# CSI + OSC sequences; stripped before matching so ANSI can't split a path.
ANSI_RE = re.compile(rb"\x1b\[[0-9;?]*[A-Za-z]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)")
# a .drv path is well under this; carrying the tail across reads lets a path
# split by a chunk boundary still match (re-seeing a name is harmless).
CARRY_BYTES = 256

DEBUG = os.environ.get("SWITCH_RPC_DEBUG", "").strip() in ("1", "true", "yes")


def log(msg: str) -> None:
    # stderr, not stdout: the wrapped command owns stdout (build logs pipe on).
    print(f"[switch-rpc] {msg}", file=sys.stderr, flush=True)


def clamp(text: str) -> str:
    text = text.strip()
    return text if len(text) <= FIELD_MAX else text[: FIELD_MAX - 1] + "…"


def connect():
    """Discord IPC handshake -> Presence, or None on any failure (fail-open)."""
    if not CLIENT_ID:
        return None
    try:
        from pypresence import Presence

        rpc = Presence(CLIENT_ID)
        rpc.connect()
        return rpc
    except Exception as exc:  # noqa: BLE001 - fail-open, see module docstring
        log(f"no presence ({exc}); running bare")
        return None


def base_activity(argv: list[str]) -> dict:
    activity = {
        "details": clamp(f"rebuilding {socket.gethostname()}"),
        "state": clamp(" ".join(argv)),
        # start=now gives Discord a live elapsed timer for the whole rebuild.
        "start": int(time.time()),
    }
    if LARGE_IMAGE:
        activity["large_image"] = LARGE_IMAGE
        activity["large_text"] = "nix"
    return activity


def push(rpc, activity: dict) -> bool:
    try:
        rpc.update(**activity)
        return True
    except Exception as exc:  # noqa: BLE001 - fail-open, see module docstring
        log(f"presence update failed ({exc}); continuing")
        return False


def cleanup(rpc) -> None:
    if rpc is None:
        return
    try:
        rpc.clear()
        rpc.close()
    except Exception:  # noqa: BLE001 - teardown is best-effort by design
        pass


class BuildTracker:
    """follows the child's output and keeps the presence state on the newest
    in-flight build, coalesced under MIN_UPDATE_INTERVAL_S."""

    def __init__(self, rpc, activity: dict) -> None:
        self._rpc = rpc
        self._activity = activity
        self._carry = b""
        self._pending: str | None = None
        self._shown: str | None = None
        # the base activity was just pushed; start the rate window from it.
        self._last_push = time.monotonic()

    def feed(self, chunk: bytes) -> None:
        text = ANSI_RE.sub(b"", self._carry + chunk)
        self._carry = text[-CARRY_BYTES:]
        for match in DRV_RE.finditer(text):
            name = match.group(1).decode("utf-8", "replace")
            if name != self._pending:
                self._pending = name
                if DEBUG:
                    log(f"saw build: {name}")
        self._maybe_push()

    def _maybe_push(self) -> None:
        if self._pending is None or self._pending == self._shown:
            return
        if time.monotonic() - self._last_push < MIN_UPDATE_INTERVAL_S:
            return
        self._activity["state"] = clamp(f"building {self._pending}")
        if push(self._rpc, self._activity):
            self._shown = self._pending
            self._last_push = time.monotonic()
            if DEBUG:
                log(f"state -> {self._activity['state']}")


def _mirror_winsize(master: int) -> None:
    # nh sizes its renderer to the tty; without this the pty defaults to 80x24
    # and the progress tree wraps. re-mirrored on every SIGWINCH.
    try:
        size = fcntl.ioctl(1, termios.TIOCGWINSZ, struct.pack("HHHH", 0, 0, 0, 0))
        fcntl.ioctl(master, termios.TIOCSWINSZ, size)
    except OSError:
        pass


def _wait(proc: subprocess.Popen) -> int:
    # ctrl-c hits the whole foreground process group, so the child already got
    # SIGINT; keep waiting for it to unwind on its own terms instead of killing
    # a rebuild that may be mid-activation.
    while True:
        try:
            return proc.wait()
        except KeyboardInterrupt:
            continue


def run_plain(argv: list[str]) -> int:
    try:
        proc = subprocess.Popen(argv)
    except OSError as exc:
        log(f"cannot run {argv[0]!r}: {exc}")
        return 127
    return _wait(proc)


def run_monitored(rpc, activity: dict, argv: list[str]) -> int:
    """run the child observing its output for build markers.

    tty stdout: child runs on a pty (keeps nh interactive), bytes forwarded
    verbatim. non-tty: plain pipe, stderr merged (nix logs to stderr).
    """
    use_pty = os.isatty(1)
    if use_pty:
        master, slave = pty.openpty()
        _mirror_winsize(master)
        signal.signal(signal.SIGWINCH, lambda *_: _mirror_winsize(master))
        out, err = slave, slave
    else:
        master, slave = None, None
        out, err = subprocess.PIPE, subprocess.STDOUT
    try:
        proc = subprocess.Popen(argv, stdout=out, stderr=err)
    except OSError as exc:
        if slave is not None:
            os.close(master)
            os.close(slave)
        log(f"cannot run {argv[0]!r}: {exc}")
        return 127
    if slave is not None:
        os.close(slave)
    read_fd = master if use_pty else proc.stdout.fileno()

    tracker = BuildTracker(rpc, activity)
    while True:
        try:
            chunk = os.read(read_fd, 65536)
        except KeyboardInterrupt:
            continue
        except OSError:
            break  # EIO: linux pty semantics when the child side closes
        if not chunk:
            break
        os.write(1, chunk)
        tracker.feed(chunk)
    if use_pty:
        os.close(master)
    return _wait(proc)


def main() -> int:
    argv = sys.argv[1:]
    if argv and argv[0] == "--":
        argv = argv[1:]
    if not argv:
        log("usage: switch-rpc [--] <command> [args...]")
        return 2

    rpc = connect()
    if rpc is None:
        return run_plain(argv)

    activity = base_activity(argv)
    if push(rpc, activity):
        # one visible heartbeat so a silent run is distinguishable from a
        # fail-open one; the wrapped command owns the rest of the output.
        log(f"presence up: {activity['details']}")
    code = run_monitored(rpc, activity, argv)
    cleanup(rpc)
    return code


if __name__ == "__main__":
    sys.exit(main())
