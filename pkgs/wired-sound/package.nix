# wired-sound: the sound half of "the OS talks back" (Serial Experiments Lain, blood
# variant). all reproducible: sox-generated tones baked into the store path + a long-lived
# objc helper that answers session state. the nushell hook (nushell.nix) plays done/fail.
#
#   bin/wired-helper       long-lived agent: afplays the unlock tone on each unlock,
#                          logs the end-card on SIGTERM (logout/shutdown). NO TTS.
#   share/connection.wav   2-note minor connection chime, played ONCE at login.
#   share/unlock.wav       single soft unlock note, played by the helper on unlock.
#   share/done.wav         gentle 2-note rise, played when a LONG command finishes clean.
#   share/fail.wav         low detuned buzz, played when a LONG command errors.
#   share/lines-hum.wav    barely-there power-line mains drone (the ambient soundbed).
#   share/crt-hum.wav      barely-there CRT flyback whine (the other ambient texture).
#   bin/wired-hum          control script for the ambient soundbed (the `hum` command).
#
# the tones are deliberately LOW, short, and a-little-WRONG (detuned, minor, no decay
# polish): presence, not a sound pack. generated with sox at BUILD time so the assets
# are reproducible and live in the closure, never recorded by hand.
#
# wiring (the launchd agents, login afplay, KeepAlive discipline) lives in
# home/modules/desktop/wired-sound.nix. afplay is OS-fixed (/usr/bin), pinned absolute
# there and here.
{
  lib,
  stdenv,
  sox,
}:
let
  # the helper shells out to afplay, an OS binary (not nix-built), so it is an absolute
  # path the store can't provide. baked in as an objc string literal.
  afplayBin = "/usr/bin/afplay";
in
stdenv.mkDerivation {
  pname = "wired-sound";
  version = "0.1.0";
  src = ./.;

  nativeBuildInputs = [ sox ];

  buildPhase = ''
    runHook preBuild

    # --- the tones, generated reproducibly with sox ---
    # connection: a 2-note minor drop (A3 -> F3, a minor sixth down), each note slightly
    # FLAT of equal temperament (218/172 instead of 220/174.6) so it reads as a-little-
    # wrong. sine, short, with a soft fade so it doesn't click. this is what login answers
    # with: the machine acknowledging you connected, not a happy startup jingle.
    sox -n -r 44100 -c 1 -b 16 n1.wav synth 0.42 sine 218   fade t 0.02 0.42 0.18 gain -n -20
    sox -n -r 44100 -c 1 -b 16 n2.wav synth 0.60 sine 172   fade t 0.02 0.60 0.30 gain -n -22
    # tiny gap between the two notes so the drop is felt, not blurred.
    sox -n -r 44100 -c 1 -b 16 gap.wav synth 0.10 sine 0
    sox n1.wav gap.wav n2.wav connection.wav

    # unlock: a single soft note, a hair sharp (331 vs C#4 277 region pulled up) and quiet.
    # the helper plays this on every unlock, so it stays the most minimal of the set: one
    # breath, low, slightly off. fade-heavy so there is no attack transient.
    sox -n -r 44100 -c 1 -b 16 unlock.wav synth 0.55 sine 331 fade t 0.04 0.55 0.40 gain -n -24

    # done: a long command finished cleanly. a gentle two-note minor RISE (E4 -> G4, the
    # mirror of the connection drop) so a build/deploy answers back when you've walked off.
    # soft and resolved, never a triumphant ding.
    sox -n -r 44100 -c 1 -b 16 d1.wav synth 0.28 sine 330 fade t 0.02 0.28 0.16 gain -n -22
    sox -n -r 44100 -c 1 -b 16 d2.wav synth 0.46 sine 392 fade t 0.02 0.46 0.26 gain -n -22
    sox d1.wav d2.wav done.wav

    # fail: a long command errored. a LOW detuned buzz (a slightly-square 96Hz, a touch
    # flat), short and a-little-wrong. it should read as the machine flinching, not an alarm.
    sox -n -r 44100 -c 1 -b 16 fail.wav synth 0.34 square 96 fade t 0.01 0.34 0.20 gain -n -22

    # --- the ambient soundbed (two textures, both barely-there, 20s exact-period loops) ---
    # lines: the power-line MAINS hum, the most Lain sound. 60Hz fundamental + 120/180 harmonics,
    # the third a touch flat (179.4) so it buzzes slightly wrong. 20s = 1200 exact 60Hz periods,
    # so the file itself loops seamlessly; gained way down (this is a room tone, not a tone).
    sox -n -r 44100 -c 1 -b 16 lines-hum.wav synth 20 sine 60 sine 120 sine 179.4 gain -n -34

    # crt: the flyback whine. ~15734Hz (NTSC horizontal) over a faint 60Hz body. near the top
    # of hearing on purpose (some won't hear the whine at all, which is itself authentic).
    sox -n -r 44100 -c 1 -b 16 crt-hum.wav synth 20 sine 15734 sine 60 gain -n -38

    # --- the helper ---
    # asset + tool paths are substituted as objc string literals (note the extra quotes:
    # the .m uses @AFPLAY_UNLOCK_TONE, so the macro must expand to a quoted C string).
    $CC -O2 -Wall -fobjc-arc ./wired-helper.m -o wired-helper \
      -framework Foundation \
      -DAFPLAY_UNLOCK_TONE='"'"$out/share/wired-sound/unlock.wav"'"' \
      -DAFPLAY_BIN='"${afplayBin}"'

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 wired-helper "$out/bin/wired-helper"
    install -Dm644 connection.wav "$out/share/wired-sound/connection.wav"
    install -Dm644 unlock.wav "$out/share/wired-sound/unlock.wav"
    install -Dm644 done.wav "$out/share/wired-sound/done.wav"
    install -Dm644 fail.wav "$out/share/wired-sound/fail.wav"
    install -Dm644 lines-hum.wav "$out/share/wired-sound/lines-hum.wav"
    install -Dm644 crt-hum.wav "$out/share/wired-sound/crt-hum.wav"

    # the ambient control script, with the share dir + afplay path substituted in.
    install -Dm755 wired-hum.sh "$out/bin/wired-hum"
    substituteInPlace "$out/bin/wired-hum" \
      --replace '@SHARE@' "$out/share/wired-sound" \
      --replace '@AFPLAY@' "${afplayBin}"
    runHook postInstall
  '';

  meta = {
    description = "Serial Experiments Lain session-sound layer (connection / unlock / end-card).";
    platforms = lib.platforms.darwin;
  };
}
