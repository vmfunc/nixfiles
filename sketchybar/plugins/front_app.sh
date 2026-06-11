#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"
source "$HOME/.config/sketchybar/icon_map.sh"

APP="${INFO:-$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)}"
[ -z "$APP" ] && exit 0

__icon_map "$APP"

sketchybar --set "$NAME" \
  label="$APP" \
  icon="$icon_result" \
  icon.font="sketchybar-app-font:Regular:16.0" \
  icon.drawing=on \
  icon.color="$LAVENDER"
