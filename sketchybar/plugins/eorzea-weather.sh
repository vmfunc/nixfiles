#!/usr/bin/env bash
# lower la noscea weather, saintcoinach/xivapi forecast calc
# u32 masks reproduce js >>> 0 truncation
# shellcheck source=/dev/null
source "$HOME/.config/sketchybar/colors.sh"

readonly EORZEA_HOUR_SECS=175
readonly WEATHER_WINDOW_SECS=1400           # 8 et hours
readonly U32_MASK=4294967295

weather_chance() {
  local unix=$1
  local window_start=$(( (unix / WEATHER_WINDOW_SECS) * WEATHER_WINDOW_SECS ))
  local bell=$(( window_start / EORZEA_HOUR_SECS ))
  local increment=$(( (bell + 8 - (bell % 8)) % 24 ))
  local total_days=$(( (window_start / (EORZEA_HOUR_SECS * 24)) & U32_MASK ))
  local calc_base=$(( total_days * 100 + increment ))
  local step1=$(( ((calc_base << 11) ^ calc_base) & U32_MASK ))
  local step2=$(( ((step1 >> 8) ^ step1) & U32_MASK ))
  echo $(( step2 % 100 ))
}

# clouds 0-19 / clear 20-49 / fair 50-69 / wind 70-79 / fog 80-89 / rain 90-99.
# FIELD label ("WX:") owned by sketchybarrc; value is the all-caps forecast, color
# encodes the weather class (no wi-* glyph in the console register).
CHANCE=$(weather_chance "$(date +%s)")
if [ "$CHANCE" -lt 20 ]; then
  COLOR="$SUBTEXT";  LABEL="CLOUDS"
elif [ "$CHANCE" -lt 50 ]; then
  COLOR="$YELLOW";   LABEL="CLEAR"
elif [ "$CHANCE" -lt 70 ]; then
  COLOR="$SKY";      LABEL="FAIR"
elif [ "$CHANCE" -lt 80 ]; then
  COLOR="$GREEN";    LABEL="WIND"
elif [ "$CHANCE" -lt 90 ]; then
  COLOR="$LAVENDER"; LABEL="FOG"
else
  COLOR="$BLUE";     LABEL="RAIN"
fi

sketchybar --set "$NAME" \
  label="$LABEL" \
  label.color="$COLOR"
