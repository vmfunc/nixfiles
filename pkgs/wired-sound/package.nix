# wired-sound: the sound half of "the OS talks back" (Serial Experiments Lain, blood
# variant). all reproducible: sox-generated tones baked into the store path + a long-lived
# objc helper that answers session state. the nushell hook (nushell.nix) plays done/fail.
#
#   bin/wired-helper       long-lived agent: unlock tone on unlock, noticed blip on USB
#                          insert, logs the end-card on SIGTERM (logout/shutdown). NO TTS.
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
  # the nix-darwin system profile path: stable across rebuilds, unlike a /nix/store hash,
  # so the tailwatch agent can bake it in and not depend on launchd's minimal PATH.
  tailscaleBin = "/run/current-system/sw/bin/tailscale";
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

    # noticed: a single soft, slightly-high blip, played when a USB device is plugged in.
    # the machine acknowledging it saw you, quietly, never an alert. a hair sharp (524 not
    # C5 523.25) so it sits a touch wrong, like everything else here.
    sox -n -r 44100 -c 1 -b 16 noticed.wav synth 0.18 sine 524 fade t 0.01 0.18 0.13 gain -n -24

    # --- the ambient soundbed (two textures, 20s exact-period loops, seamless) ---
    # lines: a real transformer / power-line hum. the PERCEIVED pitch is 120Hz, not 60Hz:
    # core magnetostriction flexes twice per 60Hz cycle, so the second harmonic dominates,
    # over a buzzy 240/360/480/600 harmonic stack (that edge is what makes it read as
    # high-voltage gear, not a sine). a second 120Hz a hair apart (120.4) beats at ~0.4Hz,
    # the slow living waver of real mains hum. sox synth can't set per-oscillator gain, so
    # each harmonic is built + gained separately then mixed. all freqs * 20s are integers,
    # so the loop is seamless. final level is healthy ambient, not barely-there.
    sox -n -r 44100 -c 1 -b 16 h1.wav  synth 20 sine 120   gain -6
    sox -n -r 44100 -c 1 -b 16 h1b.wav synth 20 sine 120.4 gain -9
    sox -n -r 44100 -c 1 -b 16 h2.wav  synth 20 sine 240   gain -12
    sox -n -r 44100 -c 1 -b 16 h3.wav  synth 20 sine 360   gain -15
    sox -n -r 44100 -c 1 -b 16 h4.wav  synth 20 sine 480   gain -20
    sox -n -r 44100 -c 1 -b 16 h5.wav  synth 20 sine 600   gain -24
    sox -n -r 44100 -c 1 -b 16 hlo.wav synth 20 sine 60    gain -14
    # corona discharge: the crackling SIZZLE of high-voltage lines. broadband noise,
    # highpassed to the "sss" region, then amplitude-modulated at 120Hz (corona is hardest
    # at each voltage peak, twice per 60Hz cycle) so it crackles IN SYNC with the hum. this
    # is what makes it read as OUTDOOR power lines, not an indoor transformer. tremolo's
    # 120Hz is seamless over 20s; the underlying noise seam is masked by the hum.
    sox -n -r 44100 -c 1 -b 16 corona.wav synth 20 whitenoise highpass 1600 tremolo 120 92 gain -23
    sox -m h1.wav h1b.wav h2.wav h3.wav h4.wav h5.wav hlo.wav corona.wav lines-mix.wav
    sox lines-mix.wav lines-hum.wav gain -n -15

    # crt: the flyback whine. ~15734Hz (NTSC horizontal) over a faint 60Hz body. near the top
    # of hearing on purpose (some won't hear the whine at all, which is itself authentic).
    sox -n -r 44100 -c 1 -b 16 crt-hum.wav synth 20 sine 15734 sine 60 gain -n -38

    # --- the helper ---
    # asset + tool paths are substituted as objc string literals (note the extra quotes:
    # the .m uses @AFPLAY_UNLOCK_TONE, so the macro must expand to a quoted C string).
    $CC -O2 -Wall -fobjc-arc ./wired-helper.m -o wired-helper \
      -framework Foundation -framework IOKit \
      -DAFPLAY_UNLOCK_TONE='"'"$out/share/wired-sound/unlock.wav"'"' \
      -DAFPLAY_NOTICED_TONE='"'"$out/share/wired-sound/noticed.wav"'"' \
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
    install -Dm644 noticed.wav "$out/share/wired-sound/noticed.wav"
    install -Dm644 lines-hum.wav "$out/share/wired-sound/lines-hum.wav"
    install -Dm644 crt-hum.wav "$out/share/wired-sound/crt-hum.wav"

    # the ambient control script, with the share dir + sox `play` path substituted in.
    # play (gapless loop) replaces afplay (which left a respawn gap) for the hum.
    install -Dm755 wired-hum.sh "$out/bin/wired-hum"
    substituteInPlace "$out/bin/wired-hum" \
      --replace '@SHARE@' "$out/share/wired-sound" \
      --replace '@PLAY@' "${sox}/bin/play"

    # the tailnet watcher, polled by a launchd agent; tailscale path baked in.
    install -Dm755 wired-tailwatch.sh "$out/bin/wired-tailwatch"
    substituteInPlace "$out/bin/wired-tailwatch" \
      --replace '@SHARE@' "$out/share/wired-sound" \
      --replace '@AFPLAY@' "${afplayBin}" \
      --replace '@TAILSCALE@' "${tailscaleBin}"
    runHook postInstall
  '';

  meta = {
    description = "Serial Experiments Lain session-sound layer (connection / unlock / end-card).";
    platforms = lib.platforms.darwin;
  };
}
