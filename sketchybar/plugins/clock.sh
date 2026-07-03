#!/usr/bin/env bash
# TIME readout. FIELD label owned by sketchybarrc; all-caps date as the value.
sketchybar --set "$NAME" label="$(date '+%a %d %b %H:%M' | tr '[:lower:]' '[:upper:]')"
