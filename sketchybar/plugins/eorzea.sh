#!/usr/bin/env bash
# 1 eorzea day = 70 real min, so ET-seconds = unix * 3600/175
source "$HOME/.config/sketchybar/colors.sh"

ET=$(($(date +%s) * 3600 / 175))
EH=$((ET / 3600 % 24))
EM=$((ET / 60 % 60))

# mdi moon-phase glyphs are 4-byte / outside the nerd font range, so plain moon
if [ "$EH" -ge 6 ] && [ "$EH" -lt 18 ]; then
  ICON="$ICON_SUN"
  COLOR="$YELLOW"
else
  ICON="$ICON_MOON"
  COLOR="$MAUVE"
fi

sketchybar --set "$NAME" \
  icon="$ICON" \
  icon.color="$COLOR" \
  label="$(printf '%02d:%02d ET' "$EH" "$EM")"
