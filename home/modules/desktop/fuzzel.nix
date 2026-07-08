# fuzzel launcher for the niri desktop (tuna). the mac's spotlight/raycast twin, dressed
# in the blood variant so it stops reading like a default dmenu: a dark translucent base
# panel, a mauve border + selection, JetBrainsMono at a legible size, rounded corners,
# a "> " prompt and app icons. colors come from rice.theme.colors so a theme.nix variant
# swap recolors the launcher with the rest of the rice.
# cross-file deps: niri.nix binds Mod+Space / Ctrl+Space / Mod+D to `fuzzel` and drops the
# standalone package (this module installs it via programs.fuzzel.enable). theme.nix owns
# rice.theme.colors; the icon-theme name must match gtk.iconTheme in niri.nix (Papirus-Dark).
{ config, ... }:
let
  c = config.rice.theme.colors;
  # fuzzel wants RRGGBBAA with no leading '#'. alpha "ff" is opaque; the base panel is
  # slightly sheer so the wallpaper bleeds through like the mac's translucent surfaces.
  rgba = alpha: hex: "${builtins.substring 1 6 hex}${alpha}";
in
{
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "JetBrainsMono Nerd Font:size=13";
        # the prompt is quoted so the trailing space survives into the rendered field.
        prompt = ''"❯ "'';
        icon-theme = "Papirus-Dark";
        icons-enabled = true;
        layer = "overlay";
        width = 40;
        lines = 12;
        horizontal-pad = 22;
        vertical-pad = 16;
        inner-pad = 10;
        line-height = 24;
        image-size-ratio = 0.9;
      };
      border = {
        width = 2;
        radius = 12;
      };
      # near-black sheer panel, soft-grey text, mauve accent for prompt/match/selection.
      colors = {
        background = rgba "f2" c.base;
        text = rgba "ff" c.text;
        prompt = rgba "ff" c.mauve;
        input = rgba "ff" c.text;
        placeholder = rgba "ff" c.subtext0;
        match = rgba "ff" c.mauve;
        selection = rgba "ff" c.surface1;
        selection-text = rgba "ff" c.text;
        selection-match = rgba "ff" c.mauve;
        counter = rgba "ff" c.subtext0;
        border = rgba "ff" c.mauve;
      };
    };
  };
}
