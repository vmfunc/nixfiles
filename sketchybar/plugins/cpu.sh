#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"

CPU=$(ps -A -o %cpu | awk '{s+=$1} END {printf "%d", s/'"$(sysctl -n hw.ncpu)"'}')

if [ "$CPU" -ge 80 ]; then
  COL="$RED"
elif [ "$CPU" -ge 50 ]; then
  COL="$PEACH"
else
  COL="$MAUVE"
fi

sketchybar --set "$NAME" label="${CPU}%" label.color="$COL" \
  --set cpu_graph graph.color="$COL" \
  --push cpu_graph "$(awk "BEGIN{print $CPU/100}")"
