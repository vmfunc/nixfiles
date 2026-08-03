# tablet-mode autopilot, session half (rice.tablet.*, home layer; system half =
# modules/nixos/tablet.nix, which owns iio-sensor-proxy). two pieces of glue the
# niri session does not ship itself:
#   - rotate daemon: follows the accelerometer via monitor-sensor and turns the
#     panel with `niri msg output transform`; touch input follows the output
#     mapping for free, so ink stays under the stylus in every orientation.
#   - osk: wvkbd on the virtual-keyboard protocol, spawned hidden, plus an `osk`
#     toggle to bind to a bar button or bind. plasma posture does not use this
#     (kwin brings maliit); this is the niri-session keyboard.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.tablet;

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
    # toggle the on-screen keyboard; first use spawns it hidden, then RTMIN
    # flips visibility (wvkbd's toggle signal), so the binding is idempotent.
    if ! ${pkgs.procps}/bin/pgrep -x wvkbd-mobintl >/dev/null; then
      ${pkgs.wvkbd}/bin/wvkbd-mobintl -L 240 --hidden &
      ${pkgs.coreutils}/bin/sleep 0.3
    fi
    ${pkgs.procps}/bin/pkill --signal RTMIN -x wvkbd-mobintl
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
