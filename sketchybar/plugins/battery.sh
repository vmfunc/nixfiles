#!/usr/bin/env bash
# BAT readout. the FIELD label ("BAT:") is owned by sketchybarrc's icon field, so
# we only drive the value + its color (color == charge state). a charging '+'
# suffix replaces the old bolt glyph to stay in the all-caps console register.
source "$HOME/.config/sketchybar/colors.sh"

INFO=$(pmset -g batt)
PCT=$(echo "$INFO" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')
[ -z "$PCT" ] && exit 0

SUFFIX=""
if echo "$INFO" | grep -q "AC Power"; then
  COLOR=$GREEN
  SUFFIX="+"
elif [ "$PCT" -ge 60 ]; then
  COLOR=$GREEN
elif [ "$PCT" -ge 40 ]; then
  COLOR=$YELLOW
elif [ "$PCT" -ge 20 ]; then
  COLOR=$PEACH
else
  COLOR=$RED
fi

sketchybar --set "$NAME" label="${PCT}%${SUFFIX}" label.color="$COLOR"
