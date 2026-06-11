#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"

VOL="${INFO:-$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)}"
MUTED=$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)

if [ "$MUTED" = "true" ] || [ "${VOL:-0}" -eq 0 ] 2>/dev/null; then
  ICON="$ICON_VOL_OFF"
elif [ "$VOL" -lt 50 ]; then
  ICON="$ICON_VOL_LOW"
else
  ICON="$ICON_VOL_HIGH"
fi

sketchybar --set "$NAME" icon="$ICON" label="${VOL}%"
