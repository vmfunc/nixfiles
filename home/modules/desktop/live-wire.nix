# live-wire-borders: make the ACTIVE jankyborders border read as a faint power
# line under current, not a static accent. jankyborders has no native animation
# (its config is a one-shot color, and the `borders` CLI only sets a value), so
# we drive it: a launchd agent loops, calling `borders active_color=0x...` every
# ~180ms, walking the accent through a low-amplitude brightness/alpha shimmer.
#
# cross-file deps:
#   - modules/darwin/jankyborders.nix owns the steady-state border + the running
#     borders service. this agent only RE-SETS active_color at runtime; the
#     declared active = theme.border.active is the value it shimmers AROUND, and
#     the value the border falls back to if this agent is ever down.
#   - accent comes from theme.palette.mauve (the wired "blood" accent). read from
#     theme, never hardcoded, so a palette swap moves the shimmer with it.
#
# why precompute the frames in nix: the loop must be cheap and must not thrash.
# all the color math (parse hex, scale brightness, clamp, reformat) happens once
# at build time. the runtime loop is just an index into a fixed array + a sleep,
# so it costs one `borders` exec + one `sleep` per tick and nothing else.
#
# subtlety is the whole point: amplitude is a few percent around the accent, a
# slow triangle wave, NOT a strobe and NOT a hue shift. it should look like the
# line is barely alive, not like a notification.
{
  lib,
  pkgs,
  theme,
  config,
  ...
}:
let
  # the accent we shimmer around. theme is the source of truth, "#rrggbb".
  accentHex = theme.palette.mauve;

  hexToInt = lib.fromHexString;
  r = hexToInt (builtins.substring 1 2 accentHex);
  g = hexToInt (builtins.substring 3 2 accentHex);
  b = hexToInt (builtins.substring 5 2 accentHex);

  # two-hex-digit formatter for a 0..255 channel (lib.toHexString has no pad).
  toHex2 =
    n:
    let
      h = lib.toHexString n;
    in
    if n < 16 then "0${h}" else h;

  clamp =
    n:
    if n < 0 then
      0
    else if n > 255 then
      255
    else
      n;

  # scale a channel by a permille factor (1000 = unchanged), integer-only so the
  # whole thing stays in nix's int domain. clamp guards the bright end.
  scaleChan = perMille: c: clamp (c * perMille / 1000);

  # build one 0xAARRGGBB frame at a given brightness (permille) and alpha (0..255).
  # jankyborders wants 0xAARRGGBB, same format as theme.border.active.
  frame =
    {
      bright,
      alpha,
    }:
    "0x"
    + toHex2 alpha
    + toHex2 (scaleChan bright r)
    + toHex2 (scaleChan bright g)
    + toHex2 (scaleChan bright b);

  # the shimmer envelope. low amplitude on BOTH axes: brightness rides ~6% above
  # to ~10% below the accent, alpha dips ~12% at the trough, so the dim frames
  # read as the current "thinning" rather than the color changing. a triangle
  # ramp (up then down) reads as a breath/pulse, not a flicker. these are the
  # only magic numbers, kept inline because the wave shape IS the design.
  steps = [
    {
      bright = 1060;
      alpha = 255;
    } # crest: a touch hotter than the accent
    {
      bright = 1030;
      alpha = 252;
    }
    {
      bright = 1000;
      alpha = 246;
    } # the accent itself
    {
      bright = 965;
      alpha = 238;
    }
    {
      bright = 930;
      alpha = 226;
    }
    {
      bright = 905;
      alpha = 224;
    } # trough: dimmest + thinnest
    {
      bright = 930;
      alpha = 226;
    }
    {
      bright = 965;
      alpha = 238;
    }
    {
      bright = 1000;
      alpha = 246;
    }
    {
      bright = 1030;
      alpha = 252;
    }
  ];

  framesList = map frame steps;
  # newline-joined so the shell reads them with a plain array literal, one exec
  # of `borders` per line, no per-tick arithmetic.
  framesShell = lib.concatMapStringsSep "\n  " (f: ''"${f}"'') framesList;

  borders = "${pkgs.jankyborders}/bin/borders";

  # ~180ms/tick. fast enough to read as continuous on a 10-frame wave (~1.8s
  # period), slow enough that the exec+sleep cost is negligible. NOT sub-100ms:
  # that would thrash `borders` for no perceptual gain.
  tickSeconds = "0.18";

  driver = pkgs.writeShellApplication {
    name = "live-wire-borders";
    runtimeInputs = [ pkgs.jankyborders ];
    text = ''
      # faint living-current shimmer over the active jankyborders border.
      # precomputed AARRGGBB frames (see live-wire.nix), cycled forever.
      frames=(
        ${framesShell}
      )

      i=0
      n=''${#frames[@]}
      while true; do
        # set only the ACTIVE color; inactive borders stay the declared value.
        ${borders} active_color="''${frames[i]}" >/dev/null 2>&1 || true
        i=$(((i + 1) % n))
        sleep ${tickSeconds}
      done
    '';
  };
in
# darwin-only: launchd.agents and the borders service do not exist on nixos.
# guarded so the module still evaluates if ever pulled into a linux profile.
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  launchd.agents.live-wire-borders = {
    enable = true;
    config = {
      ProgramArguments = [ "${driver}/bin/live-wire-borders" ];
      RunAtLoad = true;
      # KeepAlive=true is correct here: the driver is a long-lived foreground
      # loop that never forks or exits on its own, so relaunch-on-exit means
      # "the shimmer crashed, bring it back", not a fork-loop (contrast
      # music-presence.nix, where `open` forks and KeepAlive MUST be false).
      KeepAlive = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/live-wire-borders.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/live-wire-borders.log";
    };
  };
}
