#!/usr/bin/env bash
# catppuccin macchiato, 0xAARRGGBB
export BASE=0xff24273a
export MANTLE=0xff1e2030
export CRUST=0xff181926
export TEXT=0xffcad3f5
export SUBTEXT=0xffa5adcb
export SURFACE0=0xff363a4f
export SURFACE1=0xff494d64
export MAUVE=0xffc6a0f6
export BLUE=0xff8aadf4
export SKY=0xff91d7e3
export GREEN=0xffa6da95
export YELLOW=0xffeed49f
export PEACH=0xfff5a97f
export RED=0xffed8796
export LAVENDER=0xffb7bfe0

export BAR_COLOR=0xf0181926
export ITEM_BG=0xff363a4f
export ACCENT=$MAUVE
export FONT="JetBrainsMono Nerd Font"

# glyphs as octal utf-8 bytes so the file is encoding-independent
export ICON_CLOCK=$(printf '\357\200\227')      # U+F017 clock
export ICON_BAT_FULL=$(printf '\357\211\200')   # U+F240
export ICON_BAT_3=$(printf '\357\211\201')      # U+F241
export ICON_BAT_HALF=$(printf '\357\211\202')   # U+F242
export ICON_BAT_1=$(printf '\357\211\203')      # U+F243
export ICON_BAT_EMPTY=$(printf '\357\211\204')  # U+F244
export ICON_BOLT=$(printf '\357\203\247')       # U+F0E7 charging
export ICON_VOL_HIGH=$(printf '\357\200\250')   # U+F028
export ICON_VOL_LOW=$(printf '\357\200\247')    # U+F027
export ICON_VOL_OFF=$(printf '\357\200\246')    # U+F026
export ICON_CPU=$(printf '\357\213\233')        # U+F2DB microchip
export ICON_GPU=$(printf '\357\211\254')        # U+F26C display (GPU load)
export ICON_SUN=$(printf '\357\206\205')        # U+F185 sun (Eorzea day)
export ICON_MOON=$(printf '\357\206\206')       # U+F186 moon (Eorzea night)
# eorzea weather, wi-* glyphs at PUA U+E3xx (3-byte; the 4-byte MDI ones render tofu)
export ICON_WX_CLOUDS=$(printf '\356\214\222') # U+E312 wi-cloudy   (Clouds)
export ICON_WX_CLEAR=$(printf '\356\214\215')  # U+E30D wi-day-sunny (Clear Skies)
export ICON_WX_FAIR=$(printf '\356\214\202')   # U+E302 wi-day-cloudy (Fair Skies)
export ICON_WX_WIND=$(printf '\356\215\213')   # U+E34B wi-strong-wind (Wind)
export ICON_WX_FOG=$(printf '\356\214\223')    # U+E313 wi-fog      (Fog)
export ICON_WX_RAIN=$(printf '\356\214\230')   # U+E318 wi-rain     (Rain)
export ICON_BELL=$(printf '\357\203\263')       # U+F0F3 bell (github notifs)
export ICON_NET=$(printf '\357\202\254')        # U+F0AC globe (net throughput)
export ICON_DOWN=$(printf '\357\201\243')       # U+F063 arrow-down (rx)
export ICON_UP=$(printf '\357\201\242')         # U+F062 arrow-up (tx)
