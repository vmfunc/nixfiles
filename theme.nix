# theme.nix — the rice's color spine, variant-selectable.
#
# `variant` is the active palette and the ONE knob that flips the whole machine:
#   "macchiato" -> the original catppuccin macchiato (the catppuccin module drives it)
#   "wired"     -> the Serial Experiments Lain "the Wired" palette (catppuccin OFF, colors by hand)
# imported once in lib/default.nix and threaded everywhere as the `theme` specialArg.
#
# both palettes share the SAME catppuccin semantic keys (mauve/blue/green/red/...), so every
# consumer that interpolates theme.palette.<name> rethemes automatically; only the hex moves.
# the wired variant repurposes the key ROLES per the Wired design: `mauve` is the cyan accent,
# `peach`/`yellow` stay cool, and crimson is reserved to `red`/`maroon` as the lone alarm so it
# never dilutes. brightness, not hue, carries hierarchy (the show's P1-phosphor CRT logic).
let
  variant = "wired";

  palettes = {
    macchiato = {
      rosewater = "#f4dbd6";
      flamingo = "#f0c6c6";
      pink = "#f5bde6";
      mauve = "#c6a0f6";
      red = "#ed8796";
      maroon = "#ee99a0";
      peach = "#f5a97f";
      yellow = "#eed49f";
      green = "#a6da95";
      teal = "#8bd5ca";
      sky = "#91d7e3";
      sapphire = "#7dc4e4";
      blue = "#8aadf4";
      lavender = "#b7bfe0";
      text = "#cad3f5";
      subtext1 = "#b8c0e0";
      subtext0 = "#a5adcb";
      overlay2 = "#939ab7";
      overlay1 = "#8087a2";
      overlay0 = "#6e738d";
      surface2 = "#5b6078";
      surface1 = "#494d64";
      surface0 = "#363a4f";
      base = "#24273a";
      mantle = "#1e2030";
      crust = "#181926";
    };

    # the Wired: cold desaturated blue-grey "dead channel", steel fg, cyan as the network
    # glow, phosphor green as the "machine speaks" signal, crimson as the lone Knights' red.
    wired = {
      rosewater = "#c8d2dc";
      flamingo = "#b9a6b0";
      pink = "#a99cd1"; # low-chroma lavender (the Wired's muted magenta)
      mauve = "#52b6cc"; # ACCENT: cold network-glow cyan (was purple)
      red = "#e23b54"; # crimson alarm — the Knights' red, errors only
      maroon = "#ff6378"; # bright crimson
      peach = "#5a8a9a"; # kept COOL so crimson stays the only warm hue
      yellow = "#c2a85e"; # muted amber — the one warm concession, warnings only
      green = "#33ff66"; # phosphor — success / clean / "the machine answered"
      teal = "#5fe0d6";
      sky = "#76d0e0";
      sapphire = "#38b0c8";
      blue = "#6286bd"; # slate — keywords / dirs / structure
      lavender = "#8d9bd1";
      text = "#9fb6c4"; # steel fg, 9.1:1 on base
      subtext1 = "#8aa0b0";
      subtext0 = "#647a8a"; # dim fg
      overlay2 = "#56707f";
      overlay1 = "#4a6473";
      overlay0 = "#3e5667"; # comments / gutter / inactive
      surface2 = "#2b3b48";
      surface1 = "#1c2733"; # inactive border / selection
      surface0 = "#121922"; # surface / bgAlt
      base = "#0a0f14"; # bg — the dead channel
      mantle = "#070b10";
      crust = "#05080c";
    };
  };

  # the 16 ANSI colors per variant (index 0..15: black,red,green,yellow,blue,magenta,cyan,
  # white, then the bright eight). wired is the engineered Wired set; macchiato keeps stock
  # catppuccin ANSI (which the catppuccin module also supplies for its own consumers).
  terminal16 = {
    macchiato = [
      "#494d64"
      "#ed8796"
      "#a6da95"
      "#eed49f"
      "#8aadf4"
      "#c6a0f6"
      "#8bd5ca"
      "#b8c0e0"
      "#5b6078"
      "#ed8796"
      "#a6da95"
      "#eed49f"
      "#8aadf4"
      "#c6a0f6"
      "#8bd5ca"
      "#a5adcb"
    ];
    wired = [
      "#121922"
      "#e23b54"
      "#33ff66"
      "#52b6cc"
      "#6286bd"
      "#8d7fb5"
      "#04c0c7"
      "#9fb6c4"
      "#3a4a5a"
      "#ff6378"
      "#79c7ad"
      "#76d0e0"
      "#5a7bb5"
      "#a99cd1"
      "#5fe0d6"
      "#d4e2ec"
    ];
  };

  # catppuccin flavor: only consumed when the catppuccin module is on (macchiato variant).
  # kept a valid catppuccin enum value in EVERY variant so rice.theme.flavor never type-errors.
  flavorByVariant = {
    macchiato = "macchiato";
    wired = "macchiato";
  };

  wallpaperByVariant = {
    macchiato = "anime-girls_long-hair_sky.jpg";
    # TODO(wired): swap to the generated power-line-tangle wallpaper once Phase 4 lands
    wired = "anime-girls_long-hair_sky.jpg";
  };

  accent = "mauve"; # the accent SLOT (cyan in wired, mauve in macchiato)
  palette = palettes.${variant};
  accentHex = palette.${accent};
in
{
  inherit
    variant
    accent
    palette
    accentHex
    ;
  ansi16 = terminal16.${variant};
  flavor = flavorByVariant.${variant};
  wallpaperFile = wallpaperByVariant.${variant};

  # jankyborders wants 0xAARRGGBB
  border = {
    active = "0xff" + builtins.substring 1 6 accentHex;
    inactive = "0xff" + builtins.substring 1 6 palette.surface1;
  };
}
