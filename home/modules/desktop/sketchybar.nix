# sketchybar config wiring. colors.sh is GENERATED here from theme.nix so the bar palette
# can never desync from the rice (the old static colors.sh was the audit's #1 drift risk).
# no glyph exports: the all-caps console register dropped icons, plugins use text labels.
# layout lives in sketchybarrc + plugins/.
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
    export ACCENT=$MAUVE
    export FONT="JetBrainsMono Nerd Font"
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
    "sketchybar/plugins" = {
      source = ../../../sketchybar/plugins;
      recursive = true;
    };
  };
}
