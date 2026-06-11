#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"
sketchybar --set "$NAME" icon="$ICON_CLOCK" label="$(date '+%a %d %b  %H:%M')"
