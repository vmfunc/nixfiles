#!/usr/bin/env bash
# wired-tailwatch: notices when a node comes ONLINE on the tailnet and plays the soft
# connection tone. "someone joined the wired." run by a launchd StartInterval agent every
# ~30s. the FIRST run baselines silently, so it only sounds for nodes that arrive AFTER the
# watcher started, not the whole tailnet at login.
set -euo pipefail

share="@SHARE@"
afplay="@AFPLAY@"
ts="@TAILSCALE@" # the nix-darwin system path, stable across rebuilds
vol="0.30"

state="${XDG_STATE_HOME:-$HOME/.local/state}/wired-tailwatch"
seenfile="$state/online"
mkdir -p "$state"

[ -x "$ts" ] || exit 0

# online = a status line that starts with an IP (a real node row) and is NOT marked
# offline. field 2 is the hostname. sorted-unique so comm can diff it.
now="$("$ts" status 2>/dev/null | awk 'NF>=2 && /^[0-9]/ && !/offline/ {print $2}' | sort -u)"
[ -z "$now" ] && exit 0

if [ ! -f "$seenfile" ]; then
  printf '%s\n' "$now" >"$seenfile" # baseline, silent
  exit 0
fi

# nodes present now but not last time = fresh arrivals
new="$(comm -13 "$seenfile" <(printf '%s\n' "$now") || true)"
printf '%s\n' "$now" >"$seenfile"

if [ -n "$new" ]; then
  "$afplay" -v "$vol" "$share/connection.wav" >/dev/null 2>&1 &
fi
