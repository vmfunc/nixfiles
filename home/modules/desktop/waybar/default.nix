# waybar for the niri desktop, in two selectable looks.
#
# rice.bar.style picks one:
#   "console" -> the lain status-console (console.nix). flat near-black hairline
#                strip, square, no pills, FIELD:value readouts, the LINUX twin of
#                the mac's sketchybar. this was the only bar until 2026-07-31 and
#                is kept verbatim as the fallback.
#   "islands"  -> floating translucent pills (islands.nix), glyph readouts, hover
#                drawers over the media and system stacks.
# both read rice.theme.colors, so a theme.nix variant swap moves either one.
#
# the style files are plain functions, not modules: two module files both defining
# programs.waybar would collide, and a look is data, not configuration.
#
# the data-producing scripts live HERE rather than in either style, so the eorzea
# clock math and the care-file reads cannot drift apart between the two. they emit
# waybar JSON (text + class) and each style owns the formatting and the colors.
#
# cross-file deps: theme.nix owns rice.theme.colors; niri.nix owns the compositor;
# rice.care (home/modules/cli/care.nix) writes the meds marker and glass count that
# two of these scripts read. started by its own systemd user unit via
# graphical-session.target, NOT niri spawn-at-startup.
#
# rice.bar.battery gates the BAT readout: this module is shared across every niri
# host (tuna the desk box, guppy the laptop), so the battery cell is OFF by default
# and flipped on per-host, keeping a phantom BAT off a machine with no battery.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  c = config.rice.theme.colors;
  cfg = config.rice.bar;

  # 1 ET day = 70 real minutes, so ET-seconds = unix * 3600/175. day is 6..18.
  # mirrors sketchybar/plugins/eorzea.sh so the two machines never disagree.
  eorzea = pkgs.writeShellScript "waybar-eorzea" ''
    ET=$(( $(date +%s) * 3600 / 175 ))
    EH=$((ET / 3600 % 24)); EM=$((ET / 60 % 60))
    if [ "$EH" -ge 6 ] && [ "$EH" -lt 18 ]; then CLASS=day; else CLASS=night; fi
    # alt as well as class: css can color by class, but only format-icons keyed on
    # alt lets a style swap the GLYPH (sun vs moon) without the script knowing
    # which look is rendering it.
    printf '{"text":"%02d:%02d","class":"%s","alt":"%s"}\n' "$EH" "$EM" "$CLASS" "$CLASS"
  '';

  # today's glass count, written by rice.care's water nudge.
  waterCell = pkgs.writeShellScript "waybar-water" ''
    file="''${XDG_DATA_HOME:-$HOME/.local/share}/soft/water-$(date +%Y-%m-%d)"
    n="$(cat "$file" 2>/dev/null || echo 0)"
    if [ "$n" -ge 6 ]; then CLASS=met; else CLASS=thirsty; fi
    printf '{"text":"%s","class":"%s"}\n' "$n" "$CLASS"
  '';

  # the marker rice.care writes, read directly rather than asked of systemd, so a
  # click and the nag agree instantly.
  medsHeart = pkgs.writeShellScript "waybar-meds" ''
    if [ -f "''${XDG_RUNTIME_DIR:-/tmp}/care-meds-pending" ]; then
      printf '{"text":"♥","class":"pending"}\n'
    else
      printf '{"text":"♡","class":"taken"}\n'
    fi
  '';

  scripts = {
    inherit eorzea waterCell medsHeart;
  };

  look = import (if cfg.style == "islands" then ./islands.nix else ./console.nix) {
    inherit
      c
      lib
      pkgs
      cfg
      scripts
      ;
  };
in
{
  options.rice.bar = {
    style = lib.mkOption {
      type = lib.types.enum [
        "console"
        "islands"
      ];
      default = "console";
      description = ''
        Which bar look to render. "console" is the original lain status strip,
        kept verbatim; "islands" is the floating-pill redesign. Flipping this
        back is the whole undo, no other option has to move with it.
      '';
    };

    battery.enable = lib.mkEnableOption "BAT charge readout in the bar (laptop hosts only)";

    # needs rice.care with a non-empty medsTimes, which is what fills the marker
    # and installs the meds-taken command this cell clicks.
    meds.enable = lib.mkEnableOption "a meds heart in the bar, filled while a dose is pending";

    # same dependency: rice.care owns the counter this reads and the `sip`
    # command that clicking it runs.
    water.enable = lib.mkEnableOption "today's glass count in the bar";
  };

  config.programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings.mainBar = look.settings;
    style = look.css;
  };
}
