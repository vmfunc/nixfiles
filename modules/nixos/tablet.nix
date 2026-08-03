# tablet-mode autopilot, system half (rice.tablet.*, default off; minnow). the
# iio accelerometer daemon feeds auto-rotate, and plasmaSession opts into a full
# plasma 6 wayland session NEXT TO niri for tablet posture: kwin reads the
# convertible's SW_TABLET_MODE switch and flips to touch chrome, maliit is its
# on-screen keyboard. the niri-side glue (rotate daemon, osk toggle) lives in
# home/modules/desktop/tablet.nix; the greeter session picker in hosts/minnow.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.tablet;
in
{
  options.rice.tablet = {
    enable = lib.mkEnableOption "tablet-mode support (iio rotation source + touch glue)";
    plasmaSession = lib.mkEnableOption "plasma 6 as a second wayland session for tablet posture";
  };

  config = lib.mkIf cfg.enable {
    # iio-sensor-proxy: owns the accelerometer and speaks dbus; both kwin and
    # the home-layer rotate daemon consume it, so it must live at system level.
    hardware.sensor.iio.enable = true;

    # a second session, NOT a second display manager: plasma6 registers its
    # wayland session file and greetd/tuigreet lists it alongside niri.
    services.desktopManager.plasma6.enable = cfg.plasmaSession;
    environment.systemPackages = lib.optionals cfg.plasmaSession [
      # kwin's virtual keyboard is pluggable and ships EMPTY; without maliit
      # installed, plasma tablet mode has no on-screen keyboard at all.
      pkgs.maliit-keyboard
    ];
  };
}
