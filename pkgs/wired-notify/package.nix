# wired-notify: the rice's OWN notifications, styled as the machine relaying from the
# network (Serial Experiments Lain, blood variant). ALL-CAPS title prefixed "// WIRED //",
# a terse body, and the low connection tone played by hand through afplay.
#
# delivery is `osascript display notification`, NOT terminal-notifier: nixpkgs ships
# terminal-notifier as an x86_64-only binary that dies "Bad CPU type in executable" on
# Apple Silicon (it silently no-op'd under a `|| true`). osascript is arm-native and
# always present at /usr/bin. the card shows under the Script Editor identity, which is the
# tradeoff for not bundling a signed notifier app.
#
# HONEST SCOPE: macOS gives no public API to intercept or restyle a THIRD-PARTY app's
# notification. so this only governs notifications the rice itself emits; it cannot reskin
# Slack/Mail/etc. the payoff is consistency: every notification WE send reads as the wired
# talking back.
#
#   wired-notify "drive unmounted"             title defaults to "// WIRED //"
#   wired-notify "PRESENT DAY" "present time"   explicit subtitle as a second arg
#
# the tone is wired-sound's connection chime, pulled from that package's store path at
# BUILD time so the asset stays reproducible and the two packages can't drift. afplay +
# osascript are OS-fixed (/usr/bin); the tone is backgrounded so the call returns at once.
{
  lib,
  writeShellApplication,
  coreutils,
  gnused,
  wired-sound,
}:
let
  afplayBin = "/usr/bin/afplay";
  osascriptBin = "/usr/bin/osascript";
  connectionTone = "${wired-sound}/share/wired-sound/connection.wav";
  titlePrefix = "// WIRED //";
  toneVolume = "0.30"; # low on purpose: a relayed blip, never an alert
in
writeShellApplication {
  name = "wired-notify";
  runtimeInputs = [
    coreutils
    gnused
  ];
  text = ''
    # usage: wired-notify <body> [subtitle]. the title is fixed to the wired prefix; the
    # body is upcased so the whole card reads as the machine relaying, not a human typing.
    if [ "$#" -lt 1 ]; then
      printf 'wired-notify: <body> [subtitle]\n' >&2
      exit 1
    fi

    # escape for an applescript string literal: backslashes first, then double-quotes.
    esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

    body="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
    script="display notification \"$(esc "$body")\" with title \"$(esc "${titlePrefix}")\""
    if [ -n "''${2:-}" ]; then
      script="$script subtitle \"$(esc "$2")\""
    fi
    # a notification is never load-bearing; failure is non-fatal.
    ${osascriptBin} -e "$script" 2>/dev/null || true

    # the connection chime, low and backgrounded. missing-asset / no-audio-device fail silent.
    ${afplayBin} -v ${toneVolume} "${connectionTone}" >/dev/null 2>&1 &
  '';

  meta = {
    description = "Lain-styled wrapper for the rice's own notifications (// WIRED // + connection tone).";
    platforms = lib.platforms.darwin;
  };
}
