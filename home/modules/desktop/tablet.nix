# tablet-mode autopilot, session half (rice.tablet.*, home layer; system half =
# modules/nixos/tablet.nix, which owns iio-sensor-proxy). two pieces of glue the
# niri session does not ship itself:
#   - rotate daemon: follows the accelerometer via monitor-sensor and turns the
#     panel with `niri msg output transform`; touch input follows the output
#     mapping for free, so ink stays under the stylus in every orientation.
#   - osk: wvkbd on the virtual-keyboard protocol, painted from rice.theme.colors,
#     plus an `osk` toggle to hang off a key bind or a bar button. plasma posture
#     does not use this (kwin brings maliit); this is the niri-session keyboard.
#
# the keyboard's shown/hidden bit is kept HERE, not in the bar: wvkbd answers no
# query and RTMIN is a blind flip, so a marker file is the only honest source of
# truth. rice.tablet.oskStatus (the waybar cell reporter) and .oskSignal (the
# refresh signal `osk` raises) are the contract waybar/default.nix consumes.
#
# cross-file deps: theme.nix owns rice.theme.colors; waybar/islands.nix renders
# the toggle as custom/osk; niri.nix binds Mod+O to the same `osk` command.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.tablet;
  c = config.rice.theme.colors;

  # wvkbd wants bare rrggbb (optionally rrggbbaa), no leading '#'.
  hex6 = h: builtins.substring 1 6 h;

  # rounded keys only in the soft look, square in the hairline console register,
  # off the same one switch niri/mako/fuzzel read so no surface disagrees.
  keyRadius = if config.rice.look == "soft" then 8 else 0;

  # the marker: present == the keyboard is currently shown. lives in the runtime
  # dir so a reboot can never resurrect a stale "it's up" from the last session.
  oskMarker = ''"''${XDG_RUNTIME_DIR:-/tmp}/osk-shown"'';

  # painted from the palette instead of wvkbd's stock blue-grey. special keys sit
  # one surface step back from normal ones, a press flashes the accent with the
  # base color as its text (dark-on-accent, the only legible way round), and the
  # whole slab carries the same sheer the rest of the rice uses over wallpaper.
  wvkbdColors = lib.concatStringsSep " " [
    "--alpha 235"
    "--bg ${hex6 c.base}"
    "--fg ${hex6 c.surface0}"
    "--fg-sp ${hex6 c.surface1}"
    "--press ${hex6 c.mauve}"
    "--press-sp ${hex6 c.mauve}"
    "--swipe ${hex6 c.surface2}"
    "--swipe-sp ${hex6 c.surface2}"
    "--text ${hex6 c.text}"
    "--text-sp ${hex6 c.subtext0}"
    "--text-press ${hex6 c.base}"
    "--text-press-sp ${hex6 c.base}"
    "--text-swipe ${hex6 c.text}"
    "--text-swipe-sp ${hex6 c.text}"
  ];

  # niri from the session's own package (niri-flake), NOT pkgs.niri: msg speaks
  # the compositor's IPC schema, so the two must be the same build.
  niri = "${config.programs.niri.package}/bin/niri";

  # iio orientation -> niri output transform. if the panel lands sideways on
  # first real hardware test, swap the 90/270 arms; the mapping depends on the
  # panel's native mount, which no spec sheet states honestly.
  rotate = pkgs.writeShellScript "tablet-rotate" ''
    ${pkgs.iio-sensor-proxy}/bin/monitor-sensor --accel | while read -r line; do
      case "$line" in
        *"orientation changed"*) ;;
        *) continue ;;
      esac
      case "$line" in
        *bottom-up*) t=180 ;;
        *left-up*) t=90 ;;
        *right-up*) t=270 ;;
        *normal*) t=normal ;;
        *) continue ;;
      esac
      ${niri} msg output ${cfg.output} transform "$t"
    done
  '';

  osk = pkgs.writeShellScriptBin "osk" ''
    set -euo pipefail
    marker=${oskMarker}

    # NOT the old spawn-hidden-then-RTMIN dance: that raced its own `sleep 0.3`
    # (a signal delivered before wvkbd installs its handler is dropped, which left
    # the marker claiming "up" over a keyboard that never appeared). a cold start
    # comes up visible instead, so the first press has nothing to race.
    #
    # -H is the portrait height: keys get narrower when the panel turns, so the
    # slab has to get taller to keep the same finger target. -L is landscape.
    if ! ${pkgs.procps}/bin/pgrep -x wvkbd-mobintl >/dev/null; then
      ${pkgs.wvkbd}/bin/wvkbd-mobintl -H 320 -L 240 -R ${toString keyRadius} ${wvkbdColors} &
      : > "$marker"
    else
      # RTMIN is wvkbd's toggle; the marker follows it because nothing can ask
      # wvkbd which way it just went.
      ${pkgs.procps}/bin/pkill --signal RTMIN -x wvkbd-mobintl
      if [ -e "$marker" ]; then rm -f "$marker"; else : > "$marker"; fi
    fi

    # repaint the bar cell NOW rather than at its next poll, so a tap lights the
    # button in the same frame the keyboard moves.
    #
    # systemctl, NOT pkill: waybar's process comm is `.waybar-wrapped`, so a
    # `pkill -x waybar` matches nothing and the signal silently never lands (the
    # cell would then only catch up on its 10s poll). the unit is the exact
    # target and needs no name guessing. it exits nonzero on a session with no
    # bar running, which is not an error here.
    ${pkgs.systemd}/bin/systemctl --user kill \
      --signal=SIGRTMIN+${toString cfg.oskSignal} waybar.service || true
  '';

  # the bar cell's reporter: glyph + class, waybar's json contract. pgrep gates
  # the marker so a keyboard killed from outside (crash, `pkill wvkbd`) reports
  # down instead of leaving the toggle stuck lit.
  oskStatus = pkgs.writeShellScript "waybar-osk" ''
    if ${pkgs.procps}/bin/pgrep -x wvkbd-mobintl >/dev/null && [ -e ${oskMarker} ]; then
      # keyboard-off glyph while it is UP: the button says what the next tap does.
      printf '{"text":"󰌐","class":"on"}\n'
    else
      printf '{"text":"󰌌","class":"off"}\n'
    fi
  '';
in
{
  options.rice.tablet = {
    enable = lib.mkEnableOption "tablet-mode session glue (auto-rotate + on-screen keyboard)";
    output = lib.mkOption {
      type = lib.types.str;
      default = "eDP-1";
      description = "niri output name of the built-in touch panel";
    };

    # module-to-module contract, not a knob: waybar/default.nix reads both to
    # wire custom/osk, and `osk` raises the signal. internal so they stay out of
    # the host layer, where changing either half alone would silently desync.
    oskSignal = lib.mkOption {
      type = lib.types.ints.between 1 20;
      default = 4;
      internal = true;
      description = "SIGRTMIN+N that `osk` raises to repaint waybar's toggle cell";
    };

    oskStatus = lib.mkOption {
      type = lib.types.str;
      default = "${oskStatus}";
      readOnly = true;
      internal = true;
      description = "waybar-json reporter for the on-screen keyboard's shown/hidden state";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.wvkbd
      osk
    ];

    systemd.user.services.tablet-rotate = {
      Unit = {
        Description = "rotate the panel to follow the accelerometer (niri)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${rotate}";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
