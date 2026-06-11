#!/usr/bin/env bash
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:/opt/homebrew/bin:$PATH"
source "$HOME/.config/sketchybar/colors.sh"

CACHE="/tmp/sketchybar_net_$USER"
UPDATE_FREQ=3
HIDE_THRESHOLD=1024  # bytes/sec, below this in both dirs we draw=off

IFACE=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
if [ -z "$IFACE" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# grab the Link# aggregate row only; $7 = Ibytes (down), $10 = Obytes (up)
read -r RX TX < <(netstat -ibn 2>/dev/null \
  | awk -v i="$IFACE" '$1==i && $3 ~ /Link/ {print $7, $10; exit}')
if [ -z "$RX" ] || [ -z "$TX" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

NOW=$(date +%s)
if [ -r "$CACHE" ]; then read -r P_IF P_T P_RX P_TX < "$CACHE"; fi
printf '%s %s %s %s\n' "$IFACE" "$NOW" "$RX" "$TX" > "$CACHE"

# first tick, cache wipe, or route flipped interface: prime fresh, show nothing
if [ -z "${P_T:-}" ] || [ "${P_IF:-}" != "$IFACE" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

DT=$((NOW - P_T))
[ "$DT" -le 0 ] && DT=$UPDATE_FREQ

D_RX=$(((RX - P_RX) / DT))
D_TX=$(((TX - P_TX) / DT))
# counter reset / flap can go negative, clamp
[ "$D_RX" -lt 0 ] && D_RX=0
[ "$D_TX" -lt 0 ] && D_TX=0

if [ "$D_RX" -lt "$HIDE_THRESHOLD" ] && [ "$D_TX" -lt "$HIDE_THRESHOLD" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

fmt() {
  local b=$1
  if [ "$b" -ge 1048576 ]; then
    awk "BEGIN{printf \"%.1fM\", $b/1048576}"
  else
    awk "BEGIN{printf \"%dK\", $b/1024}"
  fi
}

DN=$(fmt "$D_RX")
UP=$(fmt "$D_TX")

if [ "$D_TX" -gt "$D_RX" ]; then
  COL="$PEACH"
else
  COL="$SKY"
fi

sketchybar --set "$NAME" \
  drawing=on \
  icon="$ICON_NET" \
  icon.color="$COL" \
  label="${ICON_DOWN} ${DN}  ${ICON_UP} ${UP}"
