# headless apple music -> last.fm scrobbler. mac-only (it reads Music.app via
# osascript), so it is imported from the darwin desktop profile and needs no
# platform guard. the launchd agent runs `scrobble run`, which idles and
# re-checks every minute until `scrobble auth` has written
# ~/.config/scrobble/credentials, so no secret has to exist at build/switch time.
#
# one-time setup per machine (the creds are machine-local, never in git/nix):
#   scrobble auth   # register at last.fm, link the account, write creds mode 600
{ config, pkgs, ... }:
{
  home.packages = [ pkgs.scrobble ];

  launchd.agents.scrobble = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.scrobble}/bin/scrobble"
        "run"
      ];
      # long-running poller (unlike music-presence's open-and-exit), so KeepAlive
      # is correct here: launchd relaunches it if the loop ever crashes or exits.
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/scrobble.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/scrobble.log";
    };
  };
}
