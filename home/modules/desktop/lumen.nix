# lumen: music-reactive desktop wallpaper, autostarted at login on both macs.
# the package is pkgs/lumen (surfaced via the additions overlay). wallpaper.nix still
# sets the static macchiato picture underneath as a fallback: lumen renders at the
# desktop window level above it, so if lumen is not running the static image shows.
#
# KeepAlive = true is correct here (contrast music-presence.nix, which must be false):
# lumen is itself the long-lived render process, not an `open` launcher that forks and
# returns, so relaunch-on-exit is exactly what we want.
#
# first run is TCC-gated, one-time per machine: ScreenCaptureKit needs the Screen
# Recording grant (same as `record`). nix cannot grant it. until it is granted the
# field still drifts on time, just without audio reaction; accept the prompt once.
{ config, pkgs, ... }:
{
  launchd.agents.lumen = {
    enable = true;
    config = {
      ProgramArguments = [ "${pkgs.lumen}/bin/lumen" ];
      RunAtLoad = true;
      KeepAlive = true;
      # GUI render loop wants timely scheduling, not the throttled background band
      ProcessType = "Interactive";
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/lumen.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/lumen.log";
    };
  };
}
