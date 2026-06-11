#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"

GPU=$(ioreg -r -d1 -w0 -c IOAccelerator 2>/dev/null \
  | grep -o '"Device Utilization %"=[0-9]*' | head -1 | sed 's/.*=//')
GPU=${GPU:-0}

if [ "$GPU" -ge 80 ]; then
  COL="$RED"
elif [ "$GPU" -ge 50 ]; then
  COL="$PEACH"
else
  COL="$MAUVE"
fi

sketchybar --set "$NAME" label="${GPU}%" label.color="$COL"
