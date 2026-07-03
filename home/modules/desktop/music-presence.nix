# Music Presence (ungive): now-playing -> Discord rich presence. installed as a
# cask in modules/darwin/homebrew.nix; this module only autostarts it at login.
#
# why it still works on macOS 26: Apple made the MediaRemote now-playing
# framework fully private in 15.4, which broke the old third-party readers. Music
# Presence ships ungive/mediaremote-adapter, which reads now-playing through the
# Apple-entitled /usr/bin/perl (AppleScript-to-Music.app as fallback), so Apple
# Music status keeps working without us holding a private-API entitlement.
#
# the presence needs a running Discord client that exposes the local IPC socket.
# azzie runs Vesktop (home/modules/desktop/vesktop.nix), which bundles arRPC and
# provides that socket, so no stock Discord client is required.
#
# TODO(deploy): first run is TCC-gated (one-time, per machine): the AppleScript fallback
# prompts for Automation access to Music.app. nix can't grant TCC, so accept it once. the
# mediaremote-adapter path itself needs no prompt.
{ config, ... }:
{
  launchd.agents.music-presence = {
    enable = true;
    config = {
      # launch the .app by name through LaunchServices: robust to /Applications
      # vs ~/Applications, and the macOS-blessed way to start a GUI app at login.
      ProgramArguments = [
        "/usr/bin/open"
        "-a"
        "Music Presence"
      ];
      # start once at login. KeepAlive MUST stay false: `open` forks the app and
      # returns 0 immediately, so KeepAlive=true would relaunch it in a tight loop.
      RunAtLoad = true;
      KeepAlive = false;
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/music-presence.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/music-presence.log";
    };
  };
}
