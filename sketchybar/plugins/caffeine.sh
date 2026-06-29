#!/usr/bin/env bash
# CAF:<ON|OFF>, click-to-toggle keep-awake. while ON we hold a single caffeinate
# process (tracked by pidfile) that blocks display + idle + disk + system sleep;
# a second click kills it. state is re-derived from the LIVE process on every
# render, so it survives a bar reload, and a caffeinate that died on its own
# self-heals back to OFF instead of lying ON.

# launchd hands plugins a bare PATH; restore enough to find sketchybar.
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:/opt/homebrew/bin:$PATH"
source "$HOME/.config/sketchybar/colors.sh"

CAFFEINATE="/usr/bin/caffeinate"
PIDFILE="${TMPDIR:-/tmp}/sketchybar-caffeine.pid"
LOCKDIR="${TMPDIR:-/tmp}/sketchybar-caffeine.lock"

# serialize toggles: two near-simultaneous clicks must not both pass the is_awake
# guard and each start a caffeinate (the second orphans the first, and OFF only
# kills the tracked pid). atomic mkdir is the lock; a click that loses is dropped.
# the section is microseconds (caffeinate is backgrounded), so stale locks are a
# non-issue.
if [ "$1" = "toggle" ]; then
  if ! mkdir "$LOCKDIR" 2>/dev/null; then
    exit 0
  fi
  trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT
fi

is_awake() {
  local pid
  pid=$(cat "$PIDFILE" 2>/dev/null) || return 1
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

if [ "$1" = "toggle" ]; then
  if is_awake; then
    kill "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE"
  else
    # -d display, -i idle, -m disk, -s system; no -t, so it holds until killed.
    # nohup so the assertion outlives this short-lived plugin shell.
    nohup "$CAFFEINATE" -dims >/dev/null 2>&1 &
    echo "$!" >"$PIDFILE"
  fi
fi

# a stale pidfile (process exited on its own) must not read as ON.
if [ -f "$PIDFILE" ] && ! is_awake; then
  rm -f "$PIDFILE"
fi

if is_awake; then
  sketchybar --set "$NAME" label="ON" label.color="$GREEN"
else
  sketchybar --set "$NAME" label="OFF" label.color="$SUBTEXT"
fi
