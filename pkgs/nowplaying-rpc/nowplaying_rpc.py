#!/usr/bin/env python3
"""nowplaying-rpc: macOS Now Playing -> Discord rich presence, with cover art.

WHY this exists (vs music-presence): Music Presence only reads Apple Music. the
macOS Control Center "Now Playing" surface aggregates EVERY player that adopts
MediaRemote, including browser audio via the Media Session API, so reading it
shows SoundCloud-in-the-browser, Spotify, Apple Music, etc. through one daemon.
that is the whole point: azzie plays SoundCloud in Zen, which reports here.

cover art is resolved from the public iTunes Search catalog by artist+title, so
we never host, upload, or leak the user's listening data, and we get clean
square album art as an https URL (Discord proxies external image URLs).

HARD CONSTRAINT: the Discord IPC handshake REQUIRES an application client id.
there is no way around it. it is read from NOWPLAYING_RPC_CLIENT_ID and the
daemon refuses to start without one (fail-closed). the local IPC socket itself
is provided by whatever Discord client is running; azzie runs Vesktop, whose
bundled arRPC exposes it, the same dependency Music Presence already relies on.

now-playing data comes from the `media-control` CLI (a homebrew brew, pinned in
modules/darwin/homebrew.nix). `media-control stream` emits newline-delimited
JSON: {"type":"data","diff":bool,"payload":{...}}. a diff=false payload is a
full snapshot (empty object => nothing playing); diff=true is a partial update
merged onto the last snapshot.
"""

from __future__ import annotations

import base64
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone

from pypresence import ActivityType, Presence

# media-control is a homebrew binary, not a nix package; default to the Apple
# Silicon brew prefix and allow an override for non-standard installs.
MEDIA_CONTROL_BIN = os.environ.get(
    "NOWPLAYING_RPC_MEDIA_CONTROL", "/opt/homebrew/bin/media-control"
)

# players we deliberately do NOT report, by macOS bundle id. Apple Music is owned
# by music-presence (home/modules/desktop/music-presence.nix); if we also pushed
# it, two daemons would stomp the same presence. so we defer Apple Music to it and
# cover everything else (browser SoundCloud, Spotify, ...). comma-separated env.
EXCLUDED_BUNDLE_IDS = {
    b.strip()
    for b in os.environ.get("NOWPLAYING_RPC_EXCLUDE_BUNDLES", "").split(",")
    if b.strip()
}

ITUNES_SEARCH_URL = "https://itunes.apple.com/search"
# iTunes returns a 100x100 thumbnail url; the size is encoded in the path, so we
# rewrite it to a larger square. Discord renders the large image at ~512px.
ITUNES_THUMB_SIZE = "100x100"
ARTWORK_SIZE = "512x512"
HTTP_TIMEOUT_S = 6

# Discord can only render an image from a URL it can fetch, never raw bytes. for a
# non-catalog track (a SoundCloud upload, ...) there is no public catalog URL, so
# to show the cover the player hands us we host those bytes on litterbox, an
# EPHEMERAL file host (auto-expiring), and pass Discord that link.
#
# PRIVACY: this uploads cover art + listening timing to a third party. it is
# opt-in (default off) and azzie chose it knowingly. the daemon performs the
# upload at runtime; it is NOT gated by the Claude tool sandbox.
ARTWORK_UPLOAD_ENABLED = os.environ.get(
    "NOWPLAYING_RPC_UPLOAD_ARTWORK", "0"
).lower() in ("1", "true", "yes")
LITTERBOX_API = "https://litterbox.catbox.moe/resources/internals/api.php"
LITTERBOX_EXPIRY = "1h"
# keep a cached upload URL safely under litterbox's expiry so we never hand Discord
# a link that has already died.
UPLOAD_CACHE_TTL_S = 50 * 60

# Discord rate-limits SET_ACTIVITY (~5 / 20s). we only push on a real metadata or
# play/pause change, never on the per-second elapsed ticks, and floor
# the interval so a burst of track-skips cannot trip the limit.
MIN_UPDATE_INTERVAL_S = 3
# when Discord/arRPC is not up yet, retry the whole connect+stream loop on this
# cadence instead of crash-looping under launchd.
RECONNECT_DELAY_S = 15
# status reads "Listening to <app>". pypresence's sync update wants the enum, not
# the raw int 2: it calls .value on whatever is passed and does NOT coerce ints.
ACTIVITY_TYPE_LISTENING = ActivityType.LISTENING
# Discord truncates these fields at 128 chars; do it ourselves so nothing is lost
# mid-word on their side.
FIELD_MAX = 128


def log(msg: str) -> None:
    # launchd captures stdout to the agent's log file; timestamp for triage.
    print(f"[nowplaying-rpc] {msg}", flush=True)


def clamp(text: str) -> str:
    text = text.strip()
    return text if len(text) <= FIELD_MAX else text[: FIELD_MAX - 1] + "…"


class ArtworkResolver:
    """now-playing state -> album-art url.

    ground truth first: if the player handed us the exact cover (artworkData) and
    uploading is enabled, host those bytes and use that. otherwise fall back to a
    clean public iTunes catalog url (no upload). every path is non-fatal: presence
    just goes imageless on failure, and all external IO is timeout-bounded.
    """

    def __init__(self) -> None:
        self._itunes_cache: dict[tuple[str, str], str | None] = {}
        # sha256(art bytes) -> (hosted url, expires_at); keeps us from re-uploading
        # the same cover on every pause/resume/seek of one track.
        self._upload_cache: dict[str, tuple[str, float]] = {}

    def resolve(self, state: dict) -> str | None:
        art_b64 = state.get("artworkData")
        if ARTWORK_UPLOAD_ENABLED and art_b64:
            hosted = self._hosted(art_b64, state.get("artworkMimeType") or "image/jpeg")
            if hosted:
                return hosted
        return self._itunes(state.get("artist") or "", state.get("title") or "")

    def _hosted(self, art_b64: str, mime: str) -> str | None:
        key = hashlib.sha256(art_b64.encode("ascii", "ignore")).hexdigest()
        now = time.time()
        cached = self._upload_cache.get(key)
        if cached and cached[1] > now:
            return cached[0]
        try:
            raw = base64.b64decode(art_b64)
        except ValueError:
            return None
        url = self._upload(raw, mime)
        if url:
            self._upload_cache[key] = (url, now + UPLOAD_CACHE_TTL_S)
        return url

    def _upload(self, data: bytes, mime: str) -> str | None:
        ext = "png" if "png" in mime.lower() else "jpg"
        # deterministic boundary derived from the bytes; cannot collide with the
        # payload since it is a hex digest never present verbatim in image data.
        boundary = "nprpc" + hashlib.sha1(data[:256]).hexdigest()
        body = self._multipart(
            boundary,
            {"reqtype": "fileupload", "time": LITTERBOX_EXPIRY},
            "fileToUpload",
            f"art.{ext}",
            mime,
            data,
        )
        req = urllib.request.Request(
            LITTERBOX_API,
            data=body,
            headers={
                "Content-Type": f"multipart/form-data; boundary={boundary}",
                "User-Agent": "nowplaying-rpc",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT_S) as resp:
                url = resp.read().decode("utf-8", "ignore").strip()
        except (OSError, ValueError) as exc:
            log(f"artwork upload failed: {exc}")
            return None
        if url.startswith("https://"):
            log(f"hosted cover art: {url}")
            return url
        log(f"artwork upload returned unexpected response: {url[:80]!r}")
        return None

    @staticmethod
    def _multipart(
        boundary: str,
        fields: dict[str, str],
        file_field: str,
        filename: str,
        mime: str,
        data: bytes,
    ) -> bytes:
        out: list[bytes] = []
        for name, value in fields.items():
            out.append(f"--{boundary}\r\n".encode())
            out.append(
                f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode()
            )
            out.append(f"{value}\r\n".encode())
        out.append(f"--{boundary}\r\n".encode())
        out.append(
            (
                f'Content-Disposition: form-data; name="{file_field}"; '
                f'filename="{filename}"\r\n'
            ).encode()
        )
        out.append(f"Content-Type: {mime}\r\n\r\n".encode())
        out.append(data)
        out.append(f"\r\n--{boundary}--\r\n".encode())
        return b"".join(out)

    def _itunes(self, artist: str, title: str) -> str | None:
        key = (artist.lower(), title.lower())
        if key in self._itunes_cache:
            return self._itunes_cache[key]
        url = self._itunes_lookup(artist, title)
        self._itunes_cache[key] = url
        return url

    def _itunes_lookup(self, artist: str, title: str) -> str | None:
        term = f"{artist} {title}".strip()
        if not term:
            return None
        query = urllib.parse.urlencode(
            {"term": term, "entity": "song", "limit": 1}
        )
        req = urllib.request.Request(
            f"{ITUNES_SEARCH_URL}?{query}",
            headers={"User-Agent": "nowplaying-rpc"},
        )
        try:
            with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT_S) as resp:
                data = json.load(resp)
        except (OSError, ValueError) as exc:
            log(f"artwork lookup failed for {term!r}: {exc}")
            return None
        results = data.get("results") or []
        if not results:
            return None
        thumb = results[0].get("artworkUrl100")
        if not thumb:
            return None
        return thumb.replace(ITUNES_THUMB_SIZE, ARTWORK_SIZE)


def track_key(state: dict) -> tuple:
    # identity that decides "is this a different presence": metadata + play state.
    # elapsedTime / playbackRate deliberately excluded so ticks don't trigger pushes.
    return (
        state.get("title"),
        state.get("artist"),
        state.get("album"),
        state.get("bundleIdentifier"),
        bool(state.get("playing")),
    )


def parse_epoch(timestamp: str | None) -> float | None:
    if not timestamp:
        return None
    try:
        # media-control emits RFC3339 with a trailing Z; fromisoformat wants +00:00.
        return datetime.fromisoformat(
            timestamp.replace("Z", "+00:00")
        ).timestamp()
    except ValueError:
        return None


def build_activity(state: dict, art: ArtworkResolver) -> dict | None:
    if state.get("bundleIdentifier") in EXCLUDED_BUNDLE_IDS:
        # owned by another presence daemon (see EXCLUDED_BUNDLE_IDS); stay out.
        return None

    title = (state.get("title") or "").strip()
    if not title:
        return None

    artist = (state.get("artist") or "").strip()
    album = (state.get("album") or "").strip()
    playing = bool(state.get("playing"))

    activity: dict = {
        "activity_type": ACTIVITY_TYPE_LISTENING,
        "details": clamp(title),
        # a presence "state" must be non-empty; fall back when artist is unknown.
        "state": clamp(artist) if artist else "♪",
    }

    image = art.resolve(state)
    if image:
        activity["large_image"] = image
        activity["large_text"] = clamp(album or title)

    # only a playing track gets a progress bar. start = the wall-clock instant the
    # reported elapsedTime was sampled, so Discord's bar stays accurate as time
    # passes (now - start == real elapsed). paused tracks show no timestamps.
    if playing:
        sampled_at = parse_epoch(state.get("timestamp")) or time.time()
        elapsed = float(state.get("elapsedTime") or 0.0)
        start = int(sampled_at - elapsed)
        activity["start"] = start
        duration = state.get("duration")
        if duration:
            activity["end"] = int(start + float(duration))
    else:
        activity["state"] = clamp(f"{activity['state']} · paused")

    return activity


def push(rpc: Presence, state: dict, art: ArtworkResolver) -> None:
    activity = build_activity(state, art)
    if activity is None:
        rpc.clear()
        log("nothing playing -> cleared presence")
        return
    # older pypresence builds lack activity_type; degrade to a plain "Playing".
    try:
        rpc.update(**activity)
    except TypeError:
        activity.pop("activity_type", None)
        rpc.update(**activity)
    log(f"updated: {activity.get('details')} - {activity.get('state')}")


def run_session(client_id: str, art: ArtworkResolver) -> None:
    """connect to Discord, then drive presence off the media-control stream.

    returns (does not raise) when the stream ends; raises on Discord-side errors
    so the outer loop can reconnect.
    """
    rpc = Presence(client_id)
    rpc.connect()
    log("connected to Discord IPC")

    proc = subprocess.Popen(
        [MEDIA_CONTROL_BIN, "stream"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    state: dict = {}
    last_key: tuple | None = None
    last_push = 0.0
    try:
        assert proc.stdout is not None
        for line in proc.stdout:
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if event.get("type") != "data":
                continue

            payload = event.get("payload") or {}
            if event.get("diff"):
                state.update(payload)
            else:
                # full snapshot replaces state outright; {} means nothing playing.
                state = dict(payload)

            key = track_key(state)
            if key == last_key:
                continue
            # coalesce rapid changes (track-skipping) under the rate limit.
            wait = MIN_UPDATE_INTERVAL_S - (time.time() - last_push)
            if wait > 0:
                time.sleep(wait)
            push(rpc, state, art)
            last_key = key
            last_push = time.time()
    finally:
        proc.terminate()
        try:
            rpc.close()
        except Exception:
            pass


def main() -> int:
    client_id = os.environ.get("NOWPLAYING_RPC_CLIENT_ID", "").strip()
    if not client_id:
        log(
            "NOWPLAYING_RPC_CLIENT_ID is unset; refusing to start. set a Discord "
            "application id (see rice.nowPlayingRpc.clientId)."
        )
        return 1
    if not os.path.exists(MEDIA_CONTROL_BIN):
        log(f"media-control not found at {MEDIA_CONTROL_BIN}; is the brew installed?")
        return 1

    art = ArtworkResolver()
    log("starting; waiting on Discord + now-playing")
    while True:
        try:
            run_session(client_id, art)
        except KeyboardInterrupt:
            return 0
        except Exception as exc:
            # Discord not up, socket dropped, etc. back off and retry the loop.
            log(f"session ended ({exc}); retrying in {RECONNECT_DELAY_S}s")
        time.sleep(RECONNECT_DELAY_S)


if __name__ == "__main__":
    sys.exit(main())
