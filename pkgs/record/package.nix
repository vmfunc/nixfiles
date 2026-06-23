{
  lib,
  stdenv,
  apple-sdk_15,
  darwinMinVersionHook,
  writeShellApplication,
  coreutils,
  terminal-notifier,
}:
let
  # sdk 15 for SCRecordingOutput: SCK writes the file itself, no AVAssetWriter plumbing
  helper = stdenv.mkDerivation {
    pname = "record-helper";
    version = "0.1.0";
    src = ./recorder.m;
    dontUnpack = true;

    buildInputs = [
      apple-sdk_15
      # SCRecordingOutput is macos 15+; without this the target stays at the stdenv default
      (darwinMinVersionHook "15.0")
    ];

    buildPhase = ''
      runHook preBuild
      $CC -O2 -Wall -fobjc-arc "$src" -o record-helper \
        -framework Foundation -framework CoreGraphics -framework CoreMedia \
        -framework AVFoundation -framework ScreenCaptureKit
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 record-helper "$out/bin/record-helper"
      runHook postInstall
    '';

    meta.platforms = lib.platforms.darwin;
  };
in
writeShellApplication {
  name = "record";
  runtimeInputs = [
    coreutils
    terminal-notifier
  ];
  text = ''
    # screen + system-audio recorder over the SCK helper; the mic is never opened.
    state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/record"
    outdir="$HOME/workspace/recordings"
    pidfile="$state_dir/pid"
    lastfile="$state_dir/last"
    mkdir -p "$state_dir" "$outdir"

    notify() { terminal-notifier -title "record" -message "$1" -sound Glass -appIcon "" 2>/dev/null || true; }

    running() { [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; }

    start() {
      out="$outdir/$(date +%F_%H-%M-%S).mov"
      ${helper}/bin/record-helper "$out" &
      pid="$!"
      echo "$pid" > "$pidfile"
      printf '%s\n' "$out" > "$lastfile"
      # SCK exits immediately when the screen-recording TCC grant is missing
      sleep 1
      if ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$pidfile"
        notify "✗ could not start: grant screen recording permission"
        exit 1
      fi
      notify "● recording → ''${out##*/}"
    }

    stop() {
      pid="$(cat "$pidfile")"
      kill -INT "$pid" 2>/dev/null || true
      # the helper exits once the .mov is finalized; "saved" should mean saved
      for _ in $(seq 1 100); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
      done
      rm -f "$pidfile"
      last="$(cat "$lastfile" 2>/dev/null || true)"
      notify "✓ saved ''${last##*/}"
      if [ -n "$last" ]; then printf '%s\n' "$last"; fi
    }

    case "''${1:-toggle}" in
      toggle) if running; then stop; else start; fi ;;
      stop) if running; then stop; fi ;;
      status) if running; then echo recording; else echo idle; fi ;;
      -h | --help | help)
        printf 'record: screen + system-audio recorder (ScreenCaptureKit, no mic)\n'
        printf '  record          toggle full-screen recording\n'
        printf '  record stop     stop if running\n'
        printf '  record status   recording | idle\n'
        printf '  files land in ~/workspace/recordings\n'
        ;;
      *)
        printf 'record: unknown command %s (try --help)\n' "$1" >&2
        exit 1
        ;;
    esac
  '';
}
