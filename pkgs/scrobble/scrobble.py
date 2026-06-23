#!/usr/bin/env python3
# headless apple music -> last.fm scrobbler.
#
# polls Music.app through /usr/bin/osascript (NOT the private MediaRemote API, so
# this keeps working under macOS 26's lockdown), sends now-playing on every track
# change, and scrobbles a track once it clears the last.fm threshold: played for
# at least half its length or 4 minutes, whichever comes first, and at least 30s
# long. pause time does not count (we accumulate only while player state is
# playing), so a paused track will not over-scrobble.
#
# creds (api key + shared secret + session key) live in
# ~/.config/scrobble/credentials, written once by `scrobble auth`. they never
# touch git or the nix store. env vars LASTFM_API_KEY / LASTFM_API_SECRET /
# LASTFM_SESSION_KEY override the file if you would rather inject them (e.g. a
# sops-backed launchd wrapper later).
from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from pathlib import Path

API_ROOT = "https://ws.audioscrobbler.com/2.0/"
AUTH_URL = "https://www.last.fm/api/auth/"
REGISTER_URL = "https://www.last.fm/api/account/create"
OSASCRIPT = "/usr/bin/osascript"  # fixed macOS path; launchd PATH is minimal

CREDS = Path(
    os.environ.get("SCROBBLE_CREDS", str(Path.home() / ".config" / "scrobble" / "credentials"))
)

POLL_SECONDS = 10
MIN_TRACK_SECONDS = 30  # last.fm refuses anything shorter
MAX_SCROBBLE_POINT = 240  # 4 minutes, the upper bound on "played enough"
NO_CREDS_BACKOFF = 60  # re-check for creds without needing a rebuild

# catppuccin macchiato, matches the other cozy CLIs in this repo
_MAUVE = "\033[38;5;183m"
_SUB = "\033[38;5;146m"
_GREEN = "\033[38;5;151m"
_RED = "\033[38;5;210m"
_RST = "\033[0m"


def _color() -> bool:
    return sys.stderr.isatty() and os.environ.get("NO_COLOR") is None


def log(color: str, msg: str) -> None:
    sys.stderr.write((f"{color}{msg}{_RST}" if _color() else msg) + "\n")
    sys.stderr.flush()


# ---------------------------------------------------------------------------
# credentials
# ---------------------------------------------------------------------------
def load_creds() -> dict[str, str]:
    creds: dict[str, str] = {}
    for key in ("api_key", "api_secret", "session_key"):
        val = os.environ.get("LASTFM_" + key.upper())
        if val:
            creds[key] = val
    if CREDS.is_file():
        for line in CREDS.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            creds.setdefault(key.strip(), val.strip())
    return creds


def have_full_creds(creds: dict[str, str]) -> bool:
    return all(creds.get(k) for k in ("api_key", "api_secret", "session_key"))


# ---------------------------------------------------------------------------
# last.fm api
# ---------------------------------------------------------------------------
def _sign(params: dict[str, str], secret: str) -> str:
    # api_sig = md5( concat(sorted key+value) + shared_secret ), per last.fm spec.
    # format and callback are excluded; we add format only after signing.
    raw = "".join(f"{k}{params[k]}" for k in sorted(params)) + secret
    return hashlib.md5(raw.encode("utf-8")).hexdigest()  # noqa: S324, last.fm mandates md5


def call(method: str, creds: dict[str, str], **params: object) -> dict:
    body: dict[str, str] = {"method": method, "api_key": creds["api_key"]}
    for key, val in params.items():
        if val is not None:
            body[key] = str(val)
    body["api_sig"] = _sign(body, creds["api_secret"])
    body["format"] = "json"
    data = urllib.parse.urlencode(body).encode("utf-8")
    req = urllib.request.Request(API_ROOT, data=data)  # POST  # noqa: S310, fixed https host
    with urllib.request.urlopen(req, timeout=20) as resp:
        out = json.loads(resp.read().decode("utf-8"))
    if isinstance(out, dict) and out.get("error"):
        raise RuntimeError(f"last.fm error {out['error']}: {out.get('message', '?')}")
    return out


# ---------------------------------------------------------------------------
# Music.app via osascript (guarded so we never launch it ourselves)
# ---------------------------------------------------------------------------
def _osa(script: str) -> str | None:
    try:
        res = subprocess.run(  # noqa: S603, fixed argv, no shell
            [OSASCRIPT, "-e", script],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    return res.stdout.strip() if res.returncode == 0 else None


def _music_running() -> bool:
    # check via System Events so we never spring Music.app open just to poll it
    return _osa('tell application "System Events" to (name of processes) contains "Music"') == "true"


def now_playing() -> dict | None:
    if not _music_running():
        return None
    script = (
        'tell application "Music"\n'
        "  if player state is playing then\n"
        '    return "PLAYING\n" & (get name of current track) & "\n"'
        ' & (get artist of current track) & "\n"'
        ' & (get album of current track) & "\n"'
        " & ((get duration of current track) as integer)\n"
        "  else\n"
        '    return "IDLE"\n'
        "  end if\n"
        "end tell"
    )
    raw = _osa(script)
    if not raw or not raw.startswith("PLAYING"):
        return None
    parts = raw.split("\n")
    if len(parts) < 5:
        return None
    name, artist, album, dur = parts[1], parts[2], parts[3], parts[4]
    if not name or not artist:
        return None
    try:
        duration = int(float(dur))
    except ValueError:
        duration = 0
    return {"name": name, "artist": artist, "album": album, "duration": duration}


def _ident(track: dict) -> tuple[str, str, str]:
    return (track["artist"], track["name"], track["album"])


def _meets_threshold(track: dict) -> bool:
    duration = track["duration"]
    if duration and duration < MIN_TRACK_SECONDS:
        return False
    if duration <= 0:
        # unknown length (stream/radio): only scrobble after a solid 4 minutes
        return track["played"] >= MAX_SCROBBLE_POINT
    return track["played"] >= min(duration // 2, MAX_SCROBBLE_POINT)


def _send_now_playing(creds: dict[str, str], track: dict) -> None:
    try:
        call(
            "track.updateNowPlaying",
            creds,
            sk=creds["session_key"],
            artist=track["artist"],
            track=track["name"],
            album=track["album"] or None,
            duration=track["duration"] or None,
        )
        log(_SUB, f"♪ now playing: {track['artist']} - {track['name']}")
    except (RuntimeError, urllib.error.URLError, OSError) as exc:
        log(_RED, f"now-playing failed: {exc}")


def _do_scrobble(creds: dict[str, str], track: dict) -> None:
    try:
        call(
            "track.scrobble",
            creds,
            sk=creds["session_key"],
            artist=track["artist"],
            track=track["name"],
            album=track["album"] or None,
            duration=track["duration"] or None,
            timestamp=track["start_ts"],
        )
        track["scrobbled"] = True
        log(_GREEN, f"✓ scrobbled: {track['artist']} - {track['name']}")
    except (RuntimeError, urllib.error.URLError, OSError) as exc:
        log(_RED, f"scrobble failed (will retry on next trigger): {exc}")


def _maybe_scrobble(creds: dict[str, str], track: dict | None) -> None:
    if track and not track["scrobbled"] and _meets_threshold(track):
        _do_scrobble(creds, track)


# ---------------------------------------------------------------------------
# commands
# ---------------------------------------------------------------------------
def cmd_run() -> int:
    creds = load_creds()
    while not have_full_creds(creds):
        log(_RED, "no last.fm creds yet. run `scrobble auth` once; i'll pick them up automatically.")
        time.sleep(NO_CREDS_BACKOFF)
        creds = load_creds()
    log(_MAUVE, "scrobbler up. watching Apple Music.")

    current: dict | None = None
    while True:
        try:
            playing = now_playing()
            stamp = int(time.time())
            if playing is None:
                _maybe_scrobble(creds, current)
                current = None
            elif current is None or _ident(current) != _ident(playing):
                _maybe_scrobble(creds, current)
                current = {**playing, "start_ts": stamp, "played": 0, "scrobbled": False}
                _send_now_playing(creds, current)
            else:
                current["played"] += POLL_SECONDS
                # scrobble mid-play once the threshold is cleared, so a long track
                # is recorded even if Music is quit before it finishes.
                _maybe_scrobble(creds, current)
        except Exception as exc:  # noqa: BLE001, the poller must never die on one bad tick
            log(_RED, f"tick error: {exc}")
        time.sleep(POLL_SECONDS)


def cmd_auth() -> int:
    creds = load_creds()
    api_key = creds.get("api_key") or ""
    api_secret = creds.get("api_secret") or ""
    if not api_key or not api_secret:
        log(_SUB, f"register an api app first (any name, callback can be blank): {REGISTER_URL}")
        api_key = input("api key: ").strip()
        api_secret = input("shared secret: ").strip()
    if not api_key or not api_secret:
        log(_RED, "need both an api key and a shared secret.")
        return 1
    base = {"api_key": api_key, "api_secret": api_secret}
    token = call("auth.getToken", base)["token"]
    url = f"{AUTH_URL}?api_key={api_key}&token={token}"
    log(_MAUVE, f"authorize in your browser, then come back:\n{url}")
    webbrowser.open(url)
    input("press enter once you've clicked 'Yes, allow access'... ")
    session = call("auth.getSession", base, token=token)["session"]
    CREDS.parent.mkdir(parents=True, exist_ok=True)
    CREDS.write_text(
        f"api_key = {api_key}\napi_secret = {api_secret}\nsession_key = {session['key']}\n",
        encoding="utf-8",
    )
    CREDS.chmod(0o600)
    log(_GREEN, f"✓ linked last.fm account '{session['name']}'. creds saved to {CREDS} (mode 600).")
    log(_SUB, "the running agent picks them up within a minute, no rebuild needed.")
    return 0


def cmd_now() -> int:
    track = now_playing()
    if track is None:
        log(_SUB, "nothing playing in Apple Music right now.")
        return 0
    dur = track["duration"]
    log(_MAUVE, f"{track['artist']} - {track['name']}  ({track['album']}, {dur}s)")
    return 0


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "run"
    if cmd in ("run", "daemon"):
        return cmd_run()
    if cmd in ("auth", "login"):
        return cmd_auth()
    if cmd in ("now", "status"):
        return cmd_now()
    log(_SUB, "usage: scrobble [run|auth|now]")
    return 0 if cmd in ("-h", "--help", "help") else 2


if __name__ == "__main__":
    sys.exit(main())
