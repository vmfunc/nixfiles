#!/usr/bin/env bash
# VOL readout. FIELD label ("VOL:") owned by sketchybarrc; value is the percent,
# or MUTE when silenced. no speaker glyph in the all-caps console register.
source "$HOME/.config/sketchybar/colors.sh"

VOL="${INFO:-$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)}"
MUTED=$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)

if [ "$MUTED" = "true" ] || [ "${VOL:-0}" -eq 0 ] 2>/dev/null; then
  sketchybar --set "$NAME" label="MUTE" label.color="$SUBTEXT"
else
  sketchybar --set "$NAME" label="${VOL}%" label.color="$ACCENT"
fi
