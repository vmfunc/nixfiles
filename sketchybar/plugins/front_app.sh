#!/usr/bin/env bash
# APP readout. FIELD label ("APP:") owned by sketchybarrc; value is the focused
# app name, upper-cased into the console register. the app-font glyph is dropped
# so the icon field stays the dimmed FIELD label like every other readout.
source "$HOME/.config/sketchybar/colors.sh"

APP="${INFO:-$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)}"
[ -z "$APP" ] && exit 0

sketchybar --set "$NAME" \
  label="$(printf '%s' "$APP" | tr '[:lower:]' '[:upper:]')"
