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

# ansi 256-color accents, matches the other cozy CLIs in this repo
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
def _osa(script: str, timeout: int = 10) -> str | None:
    try:
        res = subprocess.run(  # noqa: S603, fixed argv, no shell
            [OSASCRIPT, "-e", script],
            capture_output=True,
            text=True,
            timeout=timeout,
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


# ---------------------------------------------------------------------------
# retroactive backfill
# ---------------------------------------------------------------------------
# Music.app only keeps each track's LAST played date + a play count, not a full
# per-play history, so this adds one scrobble per recently-played track at its
# real last-played time. last.fm rejects timestamps backdated past its window
# (~2 weeks), so older plays cannot be backfilled at their true time; the
# api tells us which it ignored and why, and we report it honestly.
_IGNORE_NAMES = {
    "1": "artist ignored",
    "2": "track ignored",
    "3": "timestamp too old",
    "4": "timestamp too new",
    "5": "daily scrobble limit hit",
}
_BACKFILL_BATCH = 50  # last.fm's max scrobbles per request


def _library_recent(days: int) -> list[dict]:
    # collect raw track data inside the `tell` (track property reads are tell-safe),
    # then do the date math OUTSIDE it: on macOS 26 `year of <date>` and date
    # arithmetic misbehave inside a `tell application "Music"` block, so we hand the
    # played dates back out and turn them into unix timestamps in plain AppleScript.
    script = (
        "set nm to {}\nset ar to {}\nset al to {}\nset du to {}\nset pd to {}\n"
        'tell application "Music"\n'
        '  if not (exists library playlist 1) then return ""\n'
        "  set tk to (tracks of library playlist 1 whose played count > 0)\n"
        "  repeat with t in tk\n"
        "    set end of nm to ((name of t) as string)\n"
        "    set end of ar to ((artist of t) as string)\n"
        "    set end of al to ((album of t) as string)\n"
        "    set end of du to ((duration of t) as integer)\n"
        "    set end of pd to (played date of t)\n"
        "  end repeat\n"
        "end tell\n"
        'set ep to date "Thursday, January 1, 1970 12:00:00 AM"\n'
        "set off to (time to GMT)\n"
        'set out to ""\n'
        "repeat with i from 1 to (count of nm)\n"
        "  set u to (((item i of pd) - ep) - off) as integer\n"
        "  set out to out & (item i of nm) & tab & (item i of ar) & tab & (item i of al)"
        " & tab & (item i of du) & tab & u & linefeed\n"
        "end repeat\n"
        "return out"
    )
    raw = _osa(script, timeout=180)
    if not raw:
        return []
    cutoff = time.time() - days * 86400
    tracks: list[dict] = []
    for line in raw.split("\n"):
        cols = line.split("\t")
        if len(cols) != 5:
            continue
        name, artist, album, dur, stamp_s = cols
        if not name or not artist:
            continue
        try:
            stamp = int(float(stamp_s))  # AppleScript hands back e.g. 1.78e9
            duration = int(dur)
        except (ValueError, OverflowError):
            continue
        if stamp < cutoff:
            continue
        tracks.append(
            {"name": name, "artist": artist, "album": album, "duration": duration, "ts": stamp}
        )
    return tracks


def _scrobble_batch(creds: dict[str, str], batch: list[dict]) -> tuple[int, int, dict[str, int]]:
    params: dict[str, object] = {"sk": creds["session_key"]}
    for i, tr in enumerate(batch):
        params[f"artist[{i}]"] = tr["artist"]
        params[f"track[{i}]"] = tr["name"]
        params[f"timestamp[{i}]"] = tr["ts"]
        if tr["album"]:
            params[f"album[{i}]"] = tr["album"]
        if tr["duration"] > 0:
            params[f"duration[{i}]"] = tr["duration"]
    resp = call("track.scrobble", creds, **params)
    block = resp.get("scrobbles", {})
    attr = block.get("@attr", {})
    accepted = int(attr.get("accepted", 0))
    ignored = int(attr.get("ignored", 0))
    items = block.get("scrobble", [])
    if isinstance(items, dict):
        items = [items]
    reasons: dict[str, int] = {}
    for item in items:
        code = str(item.get("ignoredMessage", {}).get("code", "0"))
        if code != "0":
            reasons[code] = reasons.get(code, 0) + 1
    return accepted, ignored, reasons


def cmd_backfill(days: int) -> int:
    creds = load_creds()
    if not have_full_creds(creds):
        log(_RED, "link last.fm first: scrobble auth")
        return 1
    log(_SUB, f"reading Apple Music plays from the last {days} days...")
    tracks = _library_recent(days)
    if not tracks:
        log(_SUB, "no played tracks found in that window (or Music.app has no library here).")
        return 0
    tracks.sort(key=lambda t: t["ts"])
    log(_MAUVE, f"backfilling {len(tracks)} recently-played tracks to last.fm...")
    total_ok = total_ignored = 0
    all_reasons: dict[str, int] = {}
    for start in range(0, len(tracks), _BACKFILL_BATCH):
        batch = tracks[start : start + _BACKFILL_BATCH]
        try:
            ok, ignored, reasons = _scrobble_batch(creds, batch)
        except (RuntimeError, urllib.error.URLError, OSError) as exc:
            log(_RED, f"batch {start // _BACKFILL_BATCH + 1} failed: {exc}")
            continue
        total_ok += ok
        total_ignored += ignored
        for code, count in reasons.items():
            all_reasons[code] = all_reasons.get(code, 0) + count
        log(_SUB, f"  batch {start // _BACKFILL_BATCH + 1}: +{ok} accepted, {ignored} ignored")
        time.sleep(1)  # be gentle on the api
    log(_GREEN, f"✓ backfill done: {total_ok} scrobbled, {total_ignored} ignored.")
    for code, count in sorted(all_reasons.items()):
        log(_SUB, f"  {count} ignored: {_IGNORE_NAMES.get(code, 'code ' + code)}")
    return 0


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "run"
    if cmd in ("run", "daemon"):
        return cmd_run()
    if cmd in ("auth", "login"):
        return cmd_auth()
    if cmd in ("now", "status"):
        return cmd_now()
    if cmd == "backfill":
        days = 14
        if len(sys.argv) > 2:
            try:
                days = int(sys.argv[2])
            except ValueError:
                log(_RED, "usage: scrobble backfill [days]")
                return 2
        return cmd_backfill(days)
    log(_SUB, "usage: scrobble [run|auth|now|backfill [days]]")
    return 0 if cmd in ("-h", "--help", "help") else 2


if __name__ == "__main__":
    sys.exit(main())
