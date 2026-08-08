{ ... }:
{
  imports = [
    ../modules/cli/restic-linux.nix
    # japanese media pipeline: streamlink (live) + yt-dlp (VOD) funnel into the
    # hand-tuned mpv. see modules/nixos/apps.nix for the GUI half (hypnotix etc).
    ../modules/cli/streamlink.nix
    ../modules/cli/yt-dlp.nix
    ../modules/desktop/mpv.nix
    ../modules/desktop/jptv.nix
    # recording/streaming (pipewire portal capture + vkcapture game capture).
    ../modules/desktop/obs.nix
    ../modules/desktop/niri.nix
    ../modules/desktop/fuzzel.nix
    ../modules/desktop/mako.nix
    ../modules/desktop/swaylock.nix
    ../modules/desktop/swayosd.nix
    ../modules/desktop/waybar
    ../modules/desktop/qt.nix
    ../modules/desktop/cozy.nix
    ../modules/desktop/little.nix
    ../modules/desktop/zen.nix
    ../modules/desktop/zen-tabgrouper.nix
    ../modules/desktop/bitwarden.nix
    ../modules/desktop/nowplaying-rpc-linux.nix
    ../modules/desktop/printing.nix
    # kdeconnectd + tray indicator; remote input works because the system layer
    # ships the RemoteDesktop portal bridge (rice.kdeconnect, on for both boxes).
    ../modules/desktop/kdeconnect.nix
    # the note system: obsidian vault spine + ink tools + the ~/.plan mirror.
    # ink-ocr and the tablet/couch touch glue import here but default OFF; the
    # convertible (minnow) flips them on per host.
    ../modules/notes/obsidian.nix
    ../modules/notes/xournalpp.nix
    ../modules/notes/plan-mirror.nix
    ../modules/notes/ink-ocr.nix
    ../modules/notes/daylog.nix
    ../modules/notes/obsidian-publish.nix
    ../modules/notes/work-clock.nix
    ../modules/desktop/tablet.nix
    ../modules/desktop/couch.nix
    # `wired`: ask the vault from the terminal, answered by claude from your own
    # notes (key: secrets/anthropic.yaml -> wired-api-key, sops).
    ../modules/cli/wired.nix
  ];

  # Claude sorts open Zen tabs into named groups live (cross-platform: the host
  # manifest lands in ~/.mozilla/native-messaging-hosts on Linux). Permanent
  # install needs a signed XPI; until then develop with `zen-tabgrouper-dev`.
  rice.zenTabgrouper.enable = true;

  # sheer Zen's sidebar and toolbar over the wallpaper, page content untouched.
  # lands only where rice.zen.profilePath is set.
  # TODO(deploy): read tuna's profile id out of ~/.config/zen/profiles.ini and set
  # rice.zen.profilePath in home/tuna.nix, otherwise this is a no-op there.
  rice.zen.transparency.enable = true;

  # `cozy` winds the desk down in one word. soundUrl stays null until azzie picks
  # a stream she actually likes, the rest works without it.
  rice.cozy.enable = true;

  # `little` / `big` flip the compositor scale and warmth; `hug` comes with them.
  rice.little.enable = true;

  # every linux desktop carries the vault: one synced markdown tree (obsidian
  # sync) shared by obsidian, obsidian.nvim, the ink tools and the plan mirror.
  rice.notes.enable = true;

  # vmfunc.ink publish layer: `vault-scaffold` (site css/js + pinned community
  # plugins, copy-if-absent) and the recently.md feed timer.
  rice.notes.publish.enable = true;

  # the office clock: `work-in` / `work-out` / `work-log "..."` stamp the day
  # note in vault/work/; moc-work rolls it up, the monthly freeze bills it.
  rice.workClock.enable = true;

  # `wired "question"`: terminal ask-my-vault, answered by claude from the notes.
  rice.wired.enable = true;

  # `daylog`: opens claude on today's daily note and fills it from what actually
  # happened (claude sessions, git, ~/.plan). per-host comment fences in the note
  # mean every laptop can run it against the same synced day without clobbering.
  rice.daylog.enable = true;
}
