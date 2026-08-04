# fleet greeter: SDDM (plasma's display manager) on wayland, with the modern
# Breeze theme (the polished KDE login, not SDDM's dated built-in default). one
# shared greeter for every linux host, replacing the per-host greetd + tuigreet
# lain TTY greeter. niri is the default session; where plasma is installed
# (minnow's tablet posture, rice.tablet.plasmaSession) it appears as a selectable
# session, and the touch-friendly graphical login suits the convertible. owner
# directed switch 2026-08-04.
#
# WHY here and not per-host: all three linux boxes want the identical greeter, so
# it lives in the shared nixos spine. defaultSession is a plain assignment (not
# mkDefault) on purpose: plasma6 (minnow's tablet session) sets defaultSession =
# mkDefault "plasma", and a mkDefault here would collide with it at equal
# priority. a plain "niri" outranks plasma6's mkDefault, so niri stays the
# default session everywhere without a per-host mkForce.
#
# the Breeze theme files ship in kdePackages.plasma-workspace. plasma6 (minnow)
# already pulls that in, so the theme costs nothing there; on the niri-only boxes
# (tuna, guppy) it is added explicitly, gated so it is not pulled in twice.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  services.displayManager = {
    sddm = {
      enable = true;
      # SDDM's own wayland greeter (no X server just to draw a login box).
      wayland.enable = true;
      theme = "breeze";
    };
    defaultSession = "niri";
  };

  environment.systemPackages = lib.optionals (!config.services.desktopManager.plasma6.enable) [
    pkgs.kdePackages.plasma-workspace
  ];
}
