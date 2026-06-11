#!/usr/bin/env bash
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:$PATH"
source "$HOME/.config/sketchybar/colors.sh"

SID="$1"
FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"
OCCUPIED=$(aerospace list-windows --workspace "$SID" 2>/dev/null | grep -c .)

if [ "$SID" = "$FOCUSED" ]; then
  sketchybar --set "$NAME" \
    background.drawing=on \
    icon.highlight=on \
    background.color="$GREEN"
  sketchybar --animate sin 18 --set "$NAME" background.color="$MAUVE"
elif [ "$OCCUPIED" -gt 0 ]; then
  sketchybar --set "$NAME" \
    background.drawing=off \
    icon.highlight=off \
    icon.color="$MAUVE"
else
  sketchybar --set "$NAME" \
    background.drawing=off \
    icon.highlight=off \
    icon.color="$SUBTEXT"
fi
