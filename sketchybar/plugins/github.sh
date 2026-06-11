#!/usr/bin/env bash
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.nix-profile/bin:/opt/homebrew/bin:$PATH"
source "$HOME/.config/sketchybar/colors.sh"

COUNT=$(gh api notifications --jq 'length' 2>/dev/null)

if [[ "$COUNT" =~ ^[0-9]+$ ]] && [ "$COUNT" -gt 0 ]; then
  sketchybar --set "$NAME" \
    drawing=on \
    icon="$ICON_BELL" \
    icon.color="$RED" \
    label="$COUNT"
else
  sketchybar --set "$NAME" drawing=off
fi
