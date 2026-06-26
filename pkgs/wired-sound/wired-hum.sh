#!/usr/bin/env bash
# wired-hum: the ambient soundbed control. two textures, both barely-there: a power-line
# mains drone ("lines") and a CRT flyback whine ("crt"). toggled/switched by the `hum`
# nushell command. playback is sox `play ... repeat`, which loops the file back-to-back
# inside ONE process (gapless), instead of respawning afplay each loop (that left a ~2s
# dropout every 20s). state lives in XDG_STATE_HOME so the texture choice persists.
set -euo pipefail

share="@SHARE@"
play="@PLAY@"
# per-texture volume: the power-line drone sits up front (it's the point), the CRT whine
# stays gentler since high-frequency content is piercing. both still ambient, not music.
vol_lines="0.55"
vol_crt="0.30"

state="${XDG_STATE_HOME:-$HOME/.local/state}/wired-hum"
pidfile="$state/pid"
modefile="$state/mode"
mkdir -p "$state"

stop() {
  if [ -f "$pidfile" ]; then
    kill "$(cat "$pidfile")" 2>/dev/null || true
    rm -f "$pidfile"
  fi
  # the loop's currently-playing afplay child outlives the subshell; reap it by file match
  pkill -f "wired-sound/crt-hum.wav" 2>/dev/null || true
  pkill -f "wired-sound/lines-hum.wav" 2>/dev/null || true
}

start() {
  local file="$1" vol="$2"
  stop
  # `repeat 999999` loops the file inside one process: no afplay respawn, no gap. the wav is
  # exact-period so the file-to-file seam is phase-aligned (the corona noise seam is masked).
  "$play" -q -v "$vol" "$file" repeat 999999 >/dev/null 2>&1 &
  echo "$!" >"$pidfile"
}

running() { [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }

case "${1:-toggle}" in
off)
  stop
  echo "the hum stops."
  ;;
crt)
  echo crt >"$modefile"
  start "$share/crt-hum.wav" "$vol_crt"
  echo "crt whine. the room is awake."
  ;;
lines)
  echo lines >"$modefile"
  start "$share/lines-hum.wav" "$vol_lines"
  echo "power lines. you can hear the wired now."
  ;;
toggle)
  if running; then
    stop
    echo "the hum stops."
  else
    mode="$(cat "$modefile" 2>/dev/null || echo lines)"
    if [ "$mode" = crt ]; then
      start "$share/crt-hum.wav" "$vol_crt"
      echo "crt whine. the room is awake."
    else
      start "$share/lines-hum.wav" "$vol_lines"
      echo "power lines. you can hear the wired now."
    fi
  fi
  ;;
*)
  echo "usage: wired-hum [lines|crt|off|toggle]" >&2
  exit 1
  ;;
esac
