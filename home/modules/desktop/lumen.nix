# lumen: music-reactive desktop wallpaper, autostarted at login.
# the package is pkgs/lumen (surfaced via the additions overlay), shipped as Lumen.app.
#
# rice.lumen.enable gates it: on by default (coral, the always-on desk box), but OFF
# on otter (laptop) where the continuous screen-capture + GPU render loop is a real
# battery drain and buys nothing when the lid is shut. see home/otter.nix.
# wallpaper.nix still sets the static lain wallpaper underneath as a fallback: lumen
# renders at the desktop window level above it, so if lumen is not running it shows.
#
# KeepAlive = true is correct here (contrast music-presence.nix, which must be false):
# lumen is itself the long-lived render process, not an `open` launcher that forks and
# returns, so relaunch-on-exit is what we want. we run the binary inside the bundle
# directly (not via `open`) so launchd supervises the real process.
#
# TCC, one-time per machine AND per lumen update (the ad-hoc cdhash changes each build):
# a launchd agent cannot show the Screen Recording prompt, and a bare binary cannot hold
# its own grant. the bundle fixes this: grant it once by launching the app yourself so
# the prompt appears, then click allow:
#   open -a Lumen        # or: open the store path's Applications/Lumen.app
# the launchd instance shares the grant by code identity. lumen gates on the NON-prompting
# CGPreflightScreenCaptureAccess (so it never spams the prompt), but that check is cached
# per-process: a mid-session grant is picked up when macOS kills lumen on the grant change
# and launchd relaunches it (KeepAlive), or on next login (the grant persists). force it
# now with: launchctl kickstart -k gui/$(id -u)/org.nix-community.home.lumen
# until granted, the field still drifts on time, just without audio reaction.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.rice.lumen;
in
{
  options.rice.lumen.enable = lib.mkEnableOption "the music-reactive lumen wallpaper" // {
    default = true;
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.lumen ]; # registers Lumen.app with LaunchServices for `open -a`

    launchd.agents.lumen = {
      enable = true;
      config = {
        ProgramArguments = [ "${pkgs.lumen}/Applications/Lumen.app/Contents/MacOS/lumen" ];
        RunAtLoad = true;
        KeepAlive = true;
        # GUI render loop wants timely scheduling, not the throttled background band
        ProcessType = "Interactive";
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/lumen.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/lumen.log";
      };
    };
  };
}
