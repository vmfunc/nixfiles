# theme.nix — the rice's color spine, variant-selectable.
#
# `variant` is the active palette and the ONE knob that flips the whole machine:
#   "macchiato" -> the original catppuccin macchiato (the catppuccin module drives it)
#   "copland"   -> Serial Experiments Lain, warm amber Copland-OS CRT  (DEFAULT; catppuccin OFF)
#   "blood"     -> Serial Experiments Lain, near-black + Knights' crimson (catppuccin OFF)
# any non-macchiato variant turns the catppuccin module off and is colored by hand.
# imported once in lib/default.nix and threaded everywhere as the `theme` specialArg.
#
# both palettes share the SAME catppuccin semantic keys (mauve/blue/green/red/...), so every
# consumer that interpolates theme.palette.<name> rethemes automatically; only the hex moves.
# the wired variant repurposes the key ROLES per the Wired design: `mauve` is the cyan accent,
# `peach`/`yellow` stay cool, and crimson is reserved to `red`/`maroon` as the lone alarm so it
# never dilutes. brightness, not hue, carries hierarchy (the show's P1-phosphor CRT logic).
let
  variant = "blood";

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

    # Copland Amber (DEFAULT): the Tachibana Labs / Copland OS boot tube. warm amber/gold on
    # a warm black, an analog P1-phosphor CRT. monochrome-warm so brightness carries hierarchy;
    # rust-red is the one contrast (errors), warm yellow-green is "the machine answered".
    copland = {
      rosewater = "#e8d2a8";
      flamingo = "#e0b890";
      pink = "#e0a890";
      mauve = "#ffc24d"; # ACCENT: bright gold (was purple)
      red = "#d9442f"; # rust red — errors / the lone contrast
      maroon = "#e85a3a";
      peach = "#e89a4a"; # warm orange (fits the amber field)
      yellow = "#f0c860"; # amber-yellow — warnings
      green = "#b9c46a"; # warm yellow-green — success (amber-CRT green, not neon)
      teal = "#9ab884";
      sky = "#d6bd72";
      sapphire = "#c8a850";
      blue = "#c89a58"; # warm tan — no blue in the amber world, kept warm so it never clashes
      lavender = "#d8bd84";
      text = "#d8b25a"; # amber fg
      subtext1 = "#c4a050";
      subtext0 = "#8a6e34"; # dim
      overlay2 = "#705a28";
      overlay1 = "#5c4a22"; # comments
      overlay0 = "#4a3c1c";
      surface2 = "#382e18";
      surface1 = "#28200f"; # selection / inactive border
      surface0 = "#1a1610"; # surface
      base = "#0b0a07"; # bg — warm black
      mantle = "#080704";
      crust = "#050402";
    };

    # Blood & Static (DEFAULT): near-black with a MUTED red-ish purple (plum/wine) as the
    # accent, soft purple-grey text. toned down from crimson so it reads moody and Lain, not
    # alarming; the accent stays legible on the dark bar. red is reserved for real errors.
    blood = {
      rosewater = "#d8ccd4";
      flamingo = "#c8aab8";
      pink = "#c79ab4";
      mauve = "#bf7593"; # ACCENT: muted plum-rose (red-ish purple) — prompt/links/active
      red = "#c0667e"; # muted rose-red — errors only
      maroon = "#d07e96";
      peach = "#b07e90"; # muted mauve-peach
      yellow = "#c4a878"; # muted amber — warnings
      green = "#82a08c"; # muted sage — success
      teal = "#6f9a98";
      sky = "#8c8aa6";
      sapphire = "#9a72a0";
      blue = "#8a7aa6"; # muted purple-blue — keywords / dirs / structure
      lavender = "#b09cc0";
      text = "#c2b6c0"; # soft purple-grey fg
      subtext1 = "#a89ca6";
      subtext0 = "#948a98"; # dim, but kept legible (bar labels were too dark before)
      overlay2 = "#6e6470";
      overlay1 = "#4c4450"; # comments
      overlay0 = "#3c3442";
      surface2 = "#2a2430";
      surface1 = "#1e1824"; # selection / border
      surface0 = "#151019"; # surface
      base = "#0d0a0e"; # bg — near-black, faint purple
      mantle = "#0a070b";
      crust = "#060406";
    };
  };

  # the 16 ANSI colors per variant (index 0..15: black,red,green,yellow,blue,magenta,cyan,
  # white, then the bright eight). custom variants ship engineered sets; macchiato keeps stock
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
    copland = [
      "#28200f"
      "#d9442f"
      "#b9c46a"
      "#f0c860"
      "#c89a58"
      "#e0a06a"
      "#d8b25a"
      "#e8c88a"
      "#5c4a22"
      "#e85a3a"
      "#cdd47a"
      "#ffd870"
      "#e0b070"
      "#f0b888"
      "#ecc888"
      "#f7ecca"
    ];
    blood = [
      "#1e1824"
      "#c0667e"
      "#82a08c"
      "#c4a878"
      "#8a7aa6"
      "#bf7593"
      "#6f9a98"
      "#c2b6c0"
      "#4c4450"
      "#d07e96"
      "#9ab4a2"
      "#d4bc90"
      "#a08cc0"
      "#cf90ac"
      "#8ab4b0"
      "#e0d6dc"
    ];
  };

  # catppuccin flavor: only consumed when the catppuccin module is on (macchiato variant).
  # kept a valid catppuccin enum value in EVERY variant so rice.theme.flavor never type-errors.
  flavorByVariant = {
    macchiato = "macchiato";
    copland = "macchiato";
    blood = "macchiato";
  };

  wallpaperByVariant = {
    macchiato = "anime-girls_long-hair_sky.jpg";
    # TODO(wired): swap to the generated power-line-tangle wallpaper once it lands
    copland = "anime-girls_long-hair_sky.jpg";
    blood = "anime-girls_long-hair_sky.jpg";
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
