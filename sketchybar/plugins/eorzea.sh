#!/usr/bin/env bash
# ET readout. 1 eorzea day = 70 real min, so ET-seconds = unix * 3600/175.
# FIELD label owned by sketchybarrc; value is the eorzea clock, color encodes
# day vs night (no sun/moon glyph in the all-caps console register).
source "$HOME/.config/sketchybar/colors.sh"

ET=$(($(date +%s) * 3600 / 175))
EH=$((ET / 3600 % 24))
EM=$((ET / 60 % 60))

if [ "$EH" -ge 6 ] && [ "$EH" -lt 18 ]; then
  COLOR="$YELLOW"
else
  COLOR="$MAUVE"
fi

sketchybar --set "$NAME" \
  label="$(printf '%02d:%02d' "$EH" "$EM")" \
  label.color="$COLOR"
