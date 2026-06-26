# reproducible Serial Experiments Lain wallpaper, generated from nix so it
# rethemes per palette variant (copland / blood / macchiato) with zero binary
# assets in the public mirror. the show's signature establishing image: a
# silhouette tangle of utility poles + overhead cables against a flat tinted
# sky, over a warm-black field with a faint baseline grid and CRT scanlines.
#
# pipeline: build an SVG string from theme.palette (NEVER hardcode hex, every
# color reads `theme`), then rasterize with librsvg. librsvg, not imagemagick's
# own SVG delegate, because imagemagick's SVG support depends on which delegate
# is present at build time (rsvg vs the weak MSVG/XML reader) and we want a
# deterministic render. imagemagick is still used for the final scanline overlay
# + downscale so the 1px lines land exactly on output rows.
#
# consumed by wallpaper.nix (the osascript desktop-picture activation) and,
# optionally, by theme.wallpaperFile (see that module). darwin-gated at the
# call site, but the derivation itself is platform-agnostic.
{
  pkgs,
  lib,
  theme,
}:
let
  inherit (theme) palette;

  # "#rrggbb" -> "r,g,b" (decimal) for imagemagick's rgba() draw fill, which
  # wants decimal channels when an alpha is attached. parse each hex pair.
  hexDigit =
    c:
    {
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
    }
    .${lib.toLower c};
  hexPair =
    s: o: (hexDigit (builtins.substring o 1 s)) * 16 + hexDigit (builtins.substring (o + 1) 1 s);
  rgbTriplet =
    hex:
    let
      h = builtins.substring 1 6 hex; # drop leading '#'
    in
    "${toString (hexPair h 0)},${toString (hexPair h 2)},${toString (hexPair h 4)}";

  # ~5K canvas. brightness, not hue, carries the image (the show's P1-phosphor
  # CRT logic), so everything sits a few steps off `base` and stays low-contrast
  # enough to read terminals on top.
  width = 5120;
  height = 2880;

  # the silhouette sits along a horizon a bit below center; sky gradient fades
  # from a faint accent tint at the top down into the warm-black field.
  horizonY = 1880;

  # poles are evenly spaced verticals of varying height; cables are catenary-ish
  # quadratic curves slung between consecutive pole tops + a couple of crossarms.
  # generated in nix so the tangle is deterministic, not a checked-in asset.
  poleColor = palette.crust; # darkest: the silhouette reads as a cutout
  cableColor = palette.mantle;
  gridColor = palette.surface0; # faint baseline grid
  skyTop = palette.mauve; # THE ACCENT tint at the top of the sky
  skyBottom = palette.base; # warm black field

  # low-alpha stenciled show text. ALL-CAPS, the capital E in "nExt" is canon.
  textColor = palette.subtext0;
  presentDay = "PRESENT DAY,  PRESENT TIME";
  closeWorld = "CLOSE THE WORLD,  OPEN THE nExt";

  # poles: x positions across the field, each with a height and a small lean so
  # the tangle is irregular like the real establishing shots. all jitter is a
  # bounded `lib.mod` of a per-index linear-congruential step (kept small so the
  # numbers can't run off the canvas), NOT a raw multiply, deterministic per i.
  poleCount = 11;
  poleSpacing = width / poleCount;
  # base mast top ~520px above the horizon, plus 0..420px of bounded variation.
  poleTopY = i: horizonY - 520 - (lib.mod (i * 1103515245 + 12345) 421);
  # evenly spaced, with a small +/-20px lean so they aren't a perfect comb.
  poleX = i: poleSpacing / 2 + i * poleSpacing + (lib.mod (i * 53) 40) - 20;

  poles = lib.concatMapStringsSep "\n" (
    i:
    let
      x = poleX i;
      top = poleTopY i;
      # main mast
      mast = ''<line x1="${toString x}" y1="${toString top}" x2="${toString x}" y2="${toString horizonY}" stroke="${poleColor}" stroke-width="9"/>'';
      # two crossarms near the top, the classic telephone-pole silhouette
      arm1y = top + 70;
      arm2y = top + 150;
      arm =
        ay:
        ''<line x1="${toString (x - 95)}" y1="${toString ay}" x2="${toString (x + 95)}" y2="${toString ay}" stroke="${poleColor}" stroke-width="7"/>'';
    in
    mast + "\n" + arm arm1y + "\n" + arm arm2y
  ) (lib.range 0 (poleCount - 1));

  # cables: quadratic catenaries between consecutive pole tops, sagging below.
  # each pole pair gets a few parallel wires at slightly different sags so the
  # bundle reads as a tangle, not a single line.
  cableSags = [
    60
    110
    175
    250
  ];
  cables = lib.concatMapStringsSep "\n" (
    i:
    let
      x0 = poleX i;
      x1 = poleX (i + 1);
      y0 = poleTopY i + 60;
      y1 = poleTopY (i + 1) + 60;
      midX = (x0 + x1) / 2;
      wire =
        sag:
        let
          ctrlY = ((y0 + y1) / 2) + sag; # control point pulls the curve down
        in
        ''<path d="M ${toString x0} ${toString y0} Q ${toString midX} ${toString ctrlY} ${toString x1} ${toString y1}" fill="none" stroke="${cableColor}" stroke-width="3" opacity="0.85"/>'';
    in
    lib.concatMapStringsSep "\n" wire cableSags
  ) (lib.range 0 (poleCount - 2));

  # faint baseline grid: verticals + horizontals on a coarse pitch, very low
  # alpha so it's a texture under terminals, not a feature.
  gridPitch = 160;
  vlines = lib.concatMapStringsSep "\n" (
    i:
    let
      x = i * gridPitch;
    in
    ''<line x1="${toString x}" y1="0" x2="${toString x}" y2="${toString height}" stroke="${gridColor}" stroke-width="1" opacity="0.30"/>''
  ) (lib.range 0 (width / gridPitch));
  hlines = lib.concatMapStringsSep "\n" (
    i:
    let
      y = i * gridPitch;
    in
    ''<line x1="0" y1="${toString y}" x2="${toString width}" y2="${toString y}" stroke="${gridColor}" stroke-width="1" opacity="0.30"/>''
  ) (lib.range 0 (height / gridPitch));

  svg = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <svg xmlns="http://www.w3.org/2000/svg" width="${toString width}" height="${toString height}" viewBox="0 0 ${toString width} ${toString height}">
      <defs>
        <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="${skyTop}" stop-opacity="0.16"/>
          <stop offset="55%" stop-color="${skyTop}" stop-opacity="0.05"/>
          <stop offset="100%" stop-color="${skyBottom}" stop-opacity="0.0"/>
        </linearGradient>
      </defs>

      <!-- warm-black field -->
      <rect x="0" y="0" width="${toString width}" height="${toString height}" fill="${palette.base}"/>
      <!-- accent-tinted sky gradient over the field -->
      <rect x="0" y="0" width="${toString width}" height="${toString height}" fill="url(#sky)"/>

      <!-- faint baseline grid -->
      <g>
    ${vlines}
    ${hlines}
      </g>

      <!-- low-alpha stenciled show text, monospace caps -->
      <g font-family="monospace" font-weight="bold" fill="${textColor}" letter-spacing="14">
        <text x="240" y="360" font-size="120" opacity="0.10">${presentDay}</text>
        <text x="240" y="${toString (height - 220)}" font-size="120" opacity="0.10">${closeWorld}</text>
      </g>

      <!-- the pole + cable tangle (silhouette) -->
      <g>
    ${cables}
    ${poles}
      </g>
    </svg>
  '';

  svgFile = pkgs.writeText "lain-wallpaper.svg" svg;
in
# render the SVG, then lay 1px scanlines at low alpha across every other output
# row. the scanlines are generated as a tile and tiled over the full frame so
# the lines land on exact pixel rows after the SVG raster (sub-pixel scanlines
# would blur into a flat grey).
pkgs.runCommand "lain-wallpaper.png"
  {
    nativeBuildInputs = [
      pkgs.librsvg
      pkgs.imagemagick
    ];
  }
  ''
    # SVG -> PNG at full resolution via librsvg (deterministic delegate).
    rsvg-convert -w ${toString width} -h ${toString height} \
      -o base.png ${svgFile}

    # dither target: a dark->mid luminance ramp + the dim accent, pulled from the
    # palette and LINEARIZED so the remap below matches in linear light.
    magick \
      xc:'${palette.crust}' xc:'${palette.mantle}' xc:'${palette.base}' \
      xc:'${palette.surface0}' xc:'${palette.surface1}' xc:'${palette.overlay0}' \
      xc:'${palette.overlay1}' xc:'${palette.subtext0}' \
      +append -colorspace RGB miff:palette.miff

    # the fauux/mebious analog-decay fingerprint: Floyd-Steinberg dither the field
    # down to that ramp in LINEAR light (linearize -> dither+remap -> re-encode).
    # dithering in sRGB muddies to grey; linearizing first is what separates this
    # from amateur. the grain lands in the sky gradient + grid, the decay in the
    # substrate rather than a sticker on top.
    magick base.png -colorspace RGB \
      -dither FloydSteinberg -remap miff:palette.miff \
      -colorspace sRGB dithered.png

    # a 1px-on / 1px-off horizontal scanline tile, tinted to crust so it darkens
    # rather than greys. the drawn line carries the low alpha itself (fill rgba),
    # so a plain `over` composite blends it instead of overwriting. tiled over
    # the whole frame so the lines land on exact output rows (sub-pixel
    # scanlines blur into flat grey).
    magick -size ${toString width}x2 xc:none \
      -fill 'rgba(${rgbTriplet palette.crust},0.22)' \
      -draw 'line 0,0 ${toString width},0' \
      scanline.png
    magick -size ${toString width}x${toString height} tile:scanline.png \
      scanlines.png

    # $out is a hash with no extension, so imagemagick can't infer the encoder:
    # force PNG explicitly (png:$out) or it falls back to MIFF and macOS rejects it.
    magick dithered.png scanlines.png -compose over -composite \
      -strip "png:$out"
  ''
