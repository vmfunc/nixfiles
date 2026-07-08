# swaylock (swaylock-effects) lock screen for the niri desktop (tuna): the lain rice
# carried onto the lock screen so it stops falling back to a bare grey box. a
# screenshot+blur field with a subtle vignette over near-black, mauve ring on
# input, red on a wrong password, muted surface tones for cleared/verifying. colors
# come from rice.theme.colors so a theme.nix variant swap recolors the lock with the
# rest of the rice.
# ownership: programs.swaylock installs pkgs.swaylock-effects AND writes
# ~/.config/swaylock/config (swaylock-effects reads it). niri.nix keeps its `lock`
# let-binding pointed at the same swaylock-effects binary (Mod+Alt+L bind + swayidle
# both call it), so the binary is the one this module installs and it inherits this
# config file with no flags beyond `-f`.
# cross-file deps: theme.nix owns rice.theme.colors; niri.nix owns the Mod+Alt+L bind
# and the swayidle timeout/before-sleep that invoke swaylock.
{ config, pkgs, ... }:
let
  c = config.rice.theme.colors;
  # swaylock wants RRGGBBAA with no leading '#'. these helpers keep the config below
  # reading like the other rice modules (mako/fuzzel share the same near-black+mauve).
  rgba = alpha: hex: "${builtins.substring 1 6 hex}${alpha}";
  opaque = rgba "ff";
in
{
  programs.swaylock = {
    # enable so home-manager actually WRITES ~/.config/swaylock/config; without it
    # swaylock ran config-less and fell back to its default white screen.
    enable = true;
    package = pkgs.swaylock-effects;
    settings = {
      # the blurred frame comes from niri.nix's lockScript (grim -> imagemagick ->
      # `swaylock -i`), NOT swaylock-effects' own --screenshots, which does not
      # capture on niri. so no `screenshots`/`effect-blur` here; this file owns the
      # ring + text styling only, and `color` is the fallback if grim ever misses.
      color = builtins.substring 1 6 c.base;

      clock = true;
      indicator = true;
      indicator-radius = 100;
      indicator-thickness = 7;

      # hide the layout name (single us layout, the indicator is noise) and surface
      # failed attempts so a wrong password is visible, not silent.
      hide-keyboard-layout = true;
      show-failed-attempts = true;

      # the ring: mauve accent on normal/typing, red only on a wrong password (red is
      # the reserved alarm in the wired palettes), muted surface tones while it clears
      # or verifies. inside stays sheer near-black so the blur shows through the disc.
      ring-color = opaque c.mauve;
      ring-clear-color = opaque c.surface2;
      ring-ver-color = opaque c.blue;
      ring-wrong-color = opaque c.red;

      inside-color = rgba "cc" c.base;
      inside-clear-color = rgba "cc" c.surface1;
      inside-ver-color = rgba "cc" c.surface1;
      inside-wrong-color = rgba "cc" c.base;

      # the key-hit highlight tick that runs around the ring on each keypress.
      key-hl-color = opaque c.mauve;
      bs-hl-color = opaque c.red;

      # ring line + separators kept a hair below the ring so the ring reads as an
      # outline, matching niri's hairline-outline treatment on windows.
      line-color = opaque c.surface1;
      line-clear-color = opaque c.surface1;
      line-ver-color = opaque c.surface1;
      line-wrong-color = opaque c.surface1;
      separator-color = "00000000";

      # status text inside the disc: soft-grey normally, red on a wrong password.
      text-color = opaque c.text;
      text-clear-color = opaque c.subtext0;
      text-ver-color = opaque c.text;
      text-wrong-color = opaque c.red;
    };
  };
}
