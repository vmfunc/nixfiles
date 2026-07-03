#!/usr/bin/env python3
"""Native-messaging host for the Tabgrouper Zen extension.

It is the ONLY component that touches the Anthropic API key. The browser sends
it tab metadata ({tab_id, title, url}); it asks Claude Haiku to bucket those
tabs into named groups and sends the assignments back. The key is read from a
file (the sops-deployed secret) or an env var and never leaves this process.

Wire protocol (Mozilla native messaging): each message is a 4-byte unsigned
length prefix in NATIVE byte order followed by UTF-8 JSON. stdout carries ONLY
framed messages; everything diagnostic goes to stderr.

stdlib only -- no pip deps to package in Nix.
"""

import json
import os
import struct
import sys
import urllib.error
import urllib.request

MODEL = "claude-haiku-4-5-20251001"  # dated pin: reproducible, no alias drift
API_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_VERSION = "2023-06-01"
HTTP_TIMEOUT_S = 25
MAX_TABS = 400  # hard cap so a runaway window can't build a giant prompt
TITLE_CLAMP = 160  # trim hostile/huge titles before they hit the model

TOOL = {
    "name": "assign_groups",
    "description": "Assign every browser tab to a concise, human-readable group.",
    "input_schema": {
        "type": "object",
        "properties": {
            "assignments": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "tab_id": {"type": "string"},
                        "group_name": {"type": "string"},
                    },
                    "required": ["tab_id", "group_name"],
                },
            }
        },
        "required": ["assignments"],
    },
}


def log(*args):
    print("[tabgrouper-host]", *args, file=sys.stderr, flush=True)


# --- wire framing ----------------------------------------------------------
def read_message():
    raw_len = sys.stdin.buffer.read(4)
    if len(raw_len) < 4:
        return None  # EOF -> browser closed the port
    (length,) = struct.unpack("@I", raw_len)
    data = sys.stdin.buffer.read(length)
    if len(data) < length:
        return None
    return json.loads(data.decode("utf-8"))


def write_message(obj):
    data = json.dumps(obj).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("@I", len(data)))
    sys.stdout.buffer.write(data)
    sys.stdout.buffer.flush()


# --- key handling ----------------------------------------------------------
def load_api_key():
    """Env var (key value) wins for dev; otherwise read the secret file path."""
    direct = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    if direct:
        return direct
    key_file = None
    argv = sys.argv[1:]
    for i, a in enumerate(argv):
        if a == "--key-file" and i + 1 < len(argv):
            key_file = argv[i + 1]
        elif a.startswith("--key-file="):
            key_file = a.split("=", 1)[1]
    key_file = key_file or os.environ.get("TABGROUPER_KEY_FILE")
    if key_file and os.path.isfile(key_file):
        try:
            with open(key_file, "r", encoding="utf-8") as fh:
                return fh.read().strip()
        except OSError as err:
            log("could not read key file:", err)
    return ""


# --- classification --------------------------------------------------------
def build_system(mode, seed_buckets, current_groups, max_groups):
    lines = [
        "You sort a user's open browser tabs into a small set of named groups.",
        f"Use at most {max_groups} groups across all tabs.",
        "Group names are short (1-2 words), Title Case, human-readable "
        "(e.g. 'Research', 'FFXIV', 'Shopping', 'Work').",
        "Tabs about the same project, site, or task belong together.",
        "Assign EVERY tab_id you are given exactly once.",
    ]
    if current_groups:
        lines.append(
            "Reuse these existing group names whenever a tab fits one of them: "
            + ", ".join(current_groups)
            + "."
        )
    if mode == "hybrid" and seed_buckets:
        lines.append(
            "Strongly prefer sorting tabs into these buckets, and only invent a "
            "new group when a tab clearly fits none: " + ", ".join(seed_buckets) + "."
        )
    return "\n".join(lines)


def classify(api_key, msg):
    tabs = msg.get("tabs") or []
    if not isinstance(tabs, list) or not tabs:
        return []
    clean = []
    for t in tabs[:MAX_TABS]:
        if not isinstance(t, dict):
            continue
        tid = str(t.get("tab_id", "")).strip()
        if not tid:
            continue
        clean.append(
            {
                "tab_id": tid,
                "title": str(t.get("title", ""))[:TITLE_CLAMP],
                "url": str(t.get("url", ""))[:TITLE_CLAMP],
            }
        )
    if not clean:
        return []

    system = build_system(
        msg.get("mode", "free"),
        msg.get("seed_buckets") or [],
        msg.get("current_groups") or [],
        int(msg.get("max_groups") or 8),
    )
    max_tokens = max(512, min(4096, len(clean) * 40))
    body = {
        "model": MODEL,
        "max_tokens": max_tokens,
        "system": system,
        "messages": [
            {
                "role": "user",
                "content": "Sort these tabs:\n" + json.dumps(clean, ensure_ascii=False),
            }
        ],
        "tools": [TOOL],
        "tool_choice": {"type": "tool", "name": "assign_groups"},
    }
    req = urllib.request.Request(
        API_URL,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "x-api-key": api_key,
            "anthropic-version": ANTHROPIC_VERSION,
            "content-type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT_S) as resp:
        payload = json.loads(resp.read().decode("utf-8"))

    valid_ids = {t["tab_id"] for t in clean}
    out = []
    for block in payload.get("content", []):
        if block.get("type") != "tool_use" or block.get("name") != "assign_groups":
            continue
        for a in (block.get("input") or {}).get("assignments", []):
            if not isinstance(a, dict):
                continue
            tid = str(a.get("tab_id", "")).strip()
            name = str(a.get("group_name", "")).strip()[:40]
            if tid in valid_ids and name:
                out.append({"tab_id": tid, "group_name": name})
    return out


# --- message loop ----------------------------------------------------------
def handle(api_key, msg):
    mtype = msg.get("type")
    mid = msg.get("id")
    if mtype == "ping":
        return {"type": "pong", "id": mid, "model": MODEL, "has_key": bool(api_key)}
    if mtype == "classify":
        if not api_key:
            return {"type": "error", "id": mid, "message": "no API key available to the host"}
        try:
            return {"type": "assignments", "id": mid, "assignments": classify(api_key, msg)}
        except urllib.error.HTTPError as err:
            detail = err.read().decode("utf-8", "replace")[:300]
            log("anthropic HTTP", err.code, detail)
            return {"type": "error", "id": mid, "message": f"anthropic HTTP {err.code}"}
        except urllib.error.URLError as err:
            log("network error", err)
            return {"type": "error", "id": mid, "message": f"network error: {err.reason}"}
        except Exception as err:  # never let one bad message kill the host
            log("classify failed", repr(err))
            return {"type": "error", "id": mid, "message": "classify failed"}
    return {"type": "error", "id": mid, "message": f"unknown message type: {mtype}"}


def selftest(api_key):
    ok = bool(api_key)
    log("python", sys.version.split()[0])
    log("model", MODEL)
    log("api key present:", ok)
    return 0 if ok else 1


def main():
    api_key = load_api_key()
    if "--selftest" in sys.argv[1:]:
        return selftest(api_key)
    log("started; key", "present" if api_key else "MISSING")
    while True:
        try:
            msg = read_message()
        except json.JSONDecodeError as err:
            # the length-prefixed frame was fully consumed before the decode, so the
            # stream stays aligned on the next frame. one bad body must not kill the port.
            log("bad json frame", err)
            continue
        if msg is None:
            return 0
        if not isinstance(msg, dict):
            continue
        write_message(handle(api_key, msg))


if __name__ == "__main__":
    sys.exit(main())
