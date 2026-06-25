#!/usr/bin/env bash
# TIME readout. FIELD label owned by sketchybarrc; all-caps date as the value.
source "$HOME/.config/sketchybar/colors.sh"
sketchybar --set "$NAME" label="$(date '+%a %d %b %H:%M' | tr '[:lower:]' '[:upper:]')"
