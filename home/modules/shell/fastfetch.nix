{ config, theme, ... }:
let
  # hex "#rrggbb" -> decimal "R;G;B" for an SGR truecolor escape. fastfetch's display.color.keys
  # takes the raw escape body, so we derive it from theme.palette instead of a hardcoded rgb.
  hexVal = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    a = 10;
    b = 11;
    c = 12;
    d = 13;
    e = 14;
    f = 15;
  };
  # two lowercase hex chars at offset `off` of `h` -> a 0..255 decimal
  hexPair =
    h: off: hexVal.${builtins.substring off 1 h} * 16 + hexVal.${builtins.substring (off + 1) 1 h};
  hexToRgb =
    hex:
    let
      h = builtins.substring 1 6 hex; # drop leading '#'
    in
    "${toString (hexPair h 0)};${toString (hexPair h 2)};${toString (hexPair h 4)}";
in
{
  programs.fastfetch = {
    enable = true;
    settings = {
      logo.type = "none";
      # accent (mauve/gold) as a truecolor escape body, theme-derived so every variant recolors
      display.color.keys = "38;2;${hexToRgb theme.palette.mauve}";
      modules = [
        {
          # the machine names ITSELF as a Navi (rice.wiredName), not the real nix hostname.
          # {user-name} is fastfetch's named placeholder; the wired name takes the host slot.
          type = "title";
          format = "{user-name}@${config.rice.wiredName}";
        }
        "separator"
        "os"
        "kernel"
        "uptime"
        {
          # total only: the per-manager breakdown ("3564 (nix-system), 2149 (nix-user),
          # ...") is the longest line in the output and wraps over hyfetch's block art
          # in anything narrower than ~107 cols, smearing the logo.
          type = "packages";
          format = "{all}";
        }
        "shell"
        "wm"
        {
          # name only: the nightly's "0-unstable-2026-07-07" version datestamp is
          # noise and the second-worst wrap offender next to hyfetch art.
          type = "terminal";
          format = "{pretty-name}";
        }
        "memory"
        "break"
        {
          # the Lain epigraph as a footer line. fastfetch's {#...} placeholder takes a raw SGR
          # body, so we feed it the dim-amber truecolor derived from theme.palette.
          # NO `key` attr: current fastfetch renders an empty key as a literal "Custom:"
          # prefix; omitting the attr entirely is what prints the line bare.
          type = "custom";
          format = "{#38;2;${hexToRgb theme.palette.subtext0}}Close the world, Open the nExt";
        }
        "break"
        "colors"
      ];
    };
  };
}
