# wired-sound: "the OS talks back" (Serial Experiments Lain, blood variant). the machine
# answers session state with SPARSE, LOW, slightly-wrong sound, never a sound pack:
#   login            -> a 2-note minor connection chime, once (RunAtLoad agent, afplay -v low)
#   unlock           -> a soft note, each time (the long-lived helper's NSDistributedNC observer)
#   logout/shutdown  -> log "Close the World, Open the nExt" silently (helper SIGTERM trap, NO TTS)
#
# the auth-fail buzz is deliberately SKIPPED: macOS has no clean per-failure hook without
# fake-hacker chrome, and a buzz would be off-thesis anyway. the tones + helper come from
# pkgs/wired-sound (sox-baked assets + objc helper, modeled on pkgs/record). afplay is
# OS-fixed at /usr/bin, pinned absolute so the agent does not depend on launchd's PATH.
#
# imported only from home/profiles/desktop-darwin.nix (darwin desktops), so the launchd
# agents need no platform guard, same as autoraise.nix / music-presence.nix.
{
  config,
  pkgs,
  ...
}:
let
  wired = pkgs.wired-sound;
  connectionTone = "${wired}/share/wired-sound/connection.wav";
  # LOW on purpose: presence, not a notification. matches the helper's unlock volume.
  loginVolume = "0.30";
  logDir = "${config.home.homeDirectory}/Library/Logs";
in
{
  launchd.agents = {
    # login: play the connection chime ONCE, then exit. KeepAlive MUST stay false:
    # afplay exits when the tone finishes, KeepAlive=true would loop it forever.
    wired-connection = {
      enable = true;
      config = {
        ProgramArguments = [
          "/usr/bin/afplay"
          "-v"
          loginVolume
          connectionTone
        ];
        RunAtLoad = true;
        KeepAlive = false;
        StandardOutPath = "${logDir}/wired-connection.log";
        StandardErrorPath = "${logDir}/wired-connection.log";
      };
    };

    # the long-lived half: holds the unlock + USB observers for the session and traps
    # SIGTERM for the end-card. KeepAlive=true is correct here (unlike the afplay one-shots):
    # the helper is supposed to live the whole session, and a crash should bring the
    # observers back. it forks nothing, so there is no relaunch-loop risk.
    wired-helper = {
      enable = true;
      config = {
        ProgramArguments = [ "${wired}/bin/wired-helper" ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = "${logDir}/wired-helper.log";
        StandardErrorPath = "${logDir}/wired-helper.log";
      };
    };

    # the tailnet watcher: polls every 30s and plays the connection tone when a node comes
    # online ("someone joined the wired"). RunAtLoad baselines silently. it is a one-shot
    # poll, so KeepAlive MUST stay false (StartInterval re-runs it); it exits each time.
    wired-tailwatch = {
      enable = true;
      config = {
        ProgramArguments = [ "${wired}/bin/wired-tailwatch" ];
        RunAtLoad = true;
        KeepAlive = false;
        StartInterval = 30;
        StandardOutPath = "${logDir}/wired-tailwatch.log";
        StandardErrorPath = "${logDir}/wired-tailwatch.log";
      };
    };
  };
}
