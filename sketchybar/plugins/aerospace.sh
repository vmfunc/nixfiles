#!/usr/bin/env bash
# workspace tape glyph. lain console register: no pills, no animated fill. state
# is encoded purely as brightness/color on the bare numeral, like a lit segment:
# focused = ACCENT, occupied = TEXT, empty = dim SUBTEXT.
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:$PATH"
source "$HOME/.config/sketchybar/colors.sh"

SID="$1"
FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"
OCCUPIED=$(aerospace list-windows --workspace "$SID" 2>/dev/null | grep -c .)

if [ "$SID" = "$FOCUSED" ]; then
  sketchybar --set "$NAME" icon.color="$ACCENT"
elif [ "$OCCUPIED" -gt 0 ]; then
  sketchybar --set "$NAME" icon.color="$TEXT"
else
  sketchybar --set "$NAME" icon.color="$SUBTEXT"
fi
