# wired-notify: the rice's OWN notifications, styled as the machine relaying from the
# network (Serial Experiments Lain, blood variant). a thin terminal-notifier wrapper that
# fixes the form: ALL-CAPS title prefixed "// WIRED //", a terse body, and the low
# connection tone played by hand through afplay (NOT terminal-notifier's -sound, whose
# system chimes are too clean and too loud for this).
#
# HONEST SCOPE: macOS gives no public API to intercept or restyle a THIRD-PARTY app's
# notification. NotificationCenter delivery is owned by usernoted/the originating bundle;
# there is no supported hook short of private SPI. so this does not, and cannot, reskin
# Slack/Mail/etc. it only governs notifications the rice itself emits. the payoff is
# consistency: every notification WE send reads as the wired talking back, the others
# stay whatever the OS made them.
#
#   wired-notify "drive unmounted"            title defaults to "// WIRED //"
#   wired-notify "PRESENT DAY" "present time"  explicit subtitle as a second arg
#
# the tone is wired-sound's connection chime (the login "you connected" 2-note minor
# drop), pulled from that package's store path at BUILD time so the asset stays
# reproducible and the two packages can't drift. afplay is OS-fixed (/usr/bin), backgrounded
# so the notify call returns immediately. wiring lives wherever this is added to
# home.packages; the nushell `notify-wired` def in home/modules/shell/nushell.nix is the
# ergonomic front door.
{
  lib,
  writeShellApplication,
  coreutils,
  terminal-notifier,
  wired-sound,
}:
let
  # afplay shells out to an OS binary (not nix-built), so it is an absolute path the store
  # can't provide. pinned here exactly as wired-sound pins it.
  afplayBin = "/usr/bin/afplay";
  # the connection chime, baked from wired-sound's store path so the two never disagree.
  connectionTone = "${wired-sound}/share/wired-sound/connection.wav";
  titlePrefix = "// WIRED //";
  # low on purpose: a relayed blip, never an alert.
  toneVolume = "0.30";
in
writeShellApplication {
  name = "wired-notify";
  runtimeInputs = [
    coreutils
    terminal-notifier
  ];
  text = ''
    # usage: wired-notify <body> [subtitle]
    # body is the message line; the title is fixed to the wired prefix. an optional second
    # arg becomes the notification subtitle. the body is upcased so the whole card reads as
    # the machine relaying, not a human typing.
    if [ "$#" -lt 1 ]; then
      printf 'wired-notify: <body> [subtitle]\n' >&2
      exit 1
    fi

    body="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
    subtitle="''${2:-}"

    # -sound is deliberately omitted: we play the wired tone ourselves so the texture
    # matches wired-sound, not the OS chime set. appIcon "" suppresses the terminal-notifier
    # icon so the card stays sparse. failure is non-fatal (a notification is never load-bearing).
    if [ -n "$subtitle" ]; then
      terminal-notifier -title "${titlePrefix}" -subtitle "$subtitle" -message "$body" \
        -appIcon "" 2>/dev/null || true
    else
      terminal-notifier -title "${titlePrefix}" -message "$body" -appIcon "" 2>/dev/null || true
    fi

    # the connection chime, low and backgrounded so the call returns at once. missing-asset
    # or no-audio-device both fail closed and silent.
    ${afplayBin} -v ${toneVolume} "${connectionTone}" >/dev/null 2>&1 &
  '';

  meta = {
    description = "Lain-styled wrapper for the rice's own notifications (// WIRED // + connection tone).";
    platforms = lib.platforms.darwin;
  };
}
