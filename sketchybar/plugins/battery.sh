#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"

INFO=$(pmset -g batt)
PCT=$(echo "$INFO" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')
[ -z "$PCT" ] && exit 0

if echo "$INFO" | grep -q "AC Power"; then
  ICON="$ICON_BOLT"
  COLOR=$GREEN
elif [ "$PCT" -ge 80 ]; then
  ICON="$ICON_BAT_FULL"
  COLOR=$GREEN
elif [ "$PCT" -ge 60 ]; then
  ICON="$ICON_BAT_3"
  COLOR=$GREEN
elif [ "$PCT" -ge 40 ]; then
  ICON="$ICON_BAT_HALF"
  COLOR=$YELLOW
elif [ "$PCT" -ge 20 ]; then
  ICON="$ICON_BAT_1"
  COLOR=$PEACH
else
  ICON="$ICON_BAT_EMPTY"
  COLOR=$RED
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR" label="${PCT}%"
