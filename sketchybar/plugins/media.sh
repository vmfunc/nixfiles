#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"

MEDIA_CONTROL="$(command -v media-control || echo /opt/homebrew/bin/media-control)"
COVER="${TMPDIR:-/tmp}/sketchybar-media-cover.jpg"

case "$SENDER" in
mouse.entered)
  sketchybar --set media popup.drawing=on
  exit 0
  ;;
mouse.exited | mouse.exited.global)
  sketchybar --set media popup.drawing=off
  exit 0
  ;;
esac

# stream events can be partial, re-query get for truth
STATE="$("$MEDIA_CONTROL" get 2>/dev/null)"
TITLE="$(jq -r '.title  // empty' <<<"$STATE")"
ARTIST="$(jq -r '.artist // empty' <<<"$STATE")"
PLAYING="$(jq -r 'if .playing == true then "1" else "0" end' <<<"$STATE")"

if [ -z "$TITLE" ]; then
  sketchybar --set "$NAME" drawing=off
  sketchybar --set media.cover background.image.drawing=off 2>/dev/null
  exit 0
fi

# decode artwork only on track change, base64 on every tick pegs the bar
LAST_TITLE_FILE="${TMPDIR:-/tmp}/sketchybar-media-lasttitle"
if [ "$TITLE" != "$(cat "$LAST_TITLE_FILE" 2>/dev/null)" ]; then
  printf '%s' "$TITLE" >"$LAST_TITLE_FILE"
  # bsd base64 wants -D, gnu/nix wants -d
  ART="$(jq -r '.artworkData // empty' <<<"$STATE")"
  if [ -n "$ART" ] \
    && { printf '%s' "$ART" | base64 -d >"$COVER" 2>/dev/null || printf '%s' "$ART" | base64 -D >"$COVER" 2>/dev/null; } \
    && [ -s "$COVER" ]; then
    sketchybar --set media.cover \
      background.image="$COVER" background.image.scale=0.32 background.image.drawing=on
  else
    # no artwork or decode failed, hide so popup doesn't show stale art
    sketchybar --set media.cover background.image.drawing=off
  fi
fi

MAX=28
[ "${#TITLE}" -gt "$MAX" ] && TITLE="${TITLE:0:$MAX}…"
if [ -n "$ARTIST" ]; then LABEL="$TITLE - $ARTIST"; else LABEL="$TITLE"; fi

# FIELD label ("NOW:") owned by sketchybarrc; value dims when paused so playback
# state reads as brightness instead of a play/pause glyph.
if [ "$PLAYING" = "1" ]; then VALCOL="$TEXT"; else VALCOL="$SUBTEXT"; fi

sketchybar --set "$NAME" \
  drawing=on \
  label="$LABEL" \
  label.color="$VALCOL"
