# sketchybar config wiring. colors.sh is GENERATED here from theme.nix so the bar palette
# can never desync from the rice (the old static colors.sh was the audit's #1 drift risk).
# the glyph block stays static (encoding-independent octal utf-8). layout lives in
# sketchybarrc + plugins/.
{
  pkgs,
  lib,
  theme,
  ...
}:
let
  c = theme.palette;
  # 0xAARRGGBB from #rrggbb
  bar = hex: "0xff" + builtins.substring 1 6 hex;
  barAlpha = a: hex: "0x" + a + builtins.substring 1 6 hex;

  colorsSh = ''
    #!/usr/bin/env bash
    # GENERATED from theme.nix (variant: ${theme.variant}). edit the palette THERE, not here.
    # 0xAARRGGBB. semantic names kept from catppuccin so plugins need no changes on a reskin.
    export BASE=${bar c.base}
    export MANTLE=${bar c.mantle}
    export CRUST=${bar c.crust}
    export TEXT=${bar c.text}
    export SUBTEXT=${bar c.subtext0}
    export SURFACE0=${bar c.surface0}
    export SURFACE1=${bar c.surface1}
    export MAUVE=${bar c.mauve}
    export BLUE=${bar c.blue}
    export SKY=${bar c.sky}
    export GREEN=${bar c.green}
    export YELLOW=${bar c.yellow}
    export PEACH=${bar c.peach}
    export RED=${bar c.red}
    export LAVENDER=${bar c.lavender}

    export BAR_COLOR=${barAlpha "f0" c.crust}
    export ITEM_BG=${bar c.surface0}
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
  '';
in
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  xdg.configFile = {
    "sketchybar/sketchybarrc" = {
      source = ../../../sketchybar/sketchybarrc;
      executable = true;
    };
    "sketchybar/colors.sh" = {
      text = colorsSh;
      executable = true;
    };
    "sketchybar/icon_map.sh" = {
      source = "${pkgs.sketchybar-app-font}/bin/icon_map.sh";
      executable = true;
    };
    "sketchybar/plugins" = {
      source = ../../../sketchybar/plugins;
      recursive = true;
    };
  };
}
