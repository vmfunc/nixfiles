# `cozy`: one word that puts the desk to bed. warms + dims the screen, silences
# notifications, and (if rice.cozy.soundUrl is set) starts a soft loop.
#
# every step is undone by `cozy off`, so state lives in one runtime dir rather
# than being inferred from the compositor: gammastep and mpv are killed by pid,
# brightness comes back from brightnessctl's own saved value.
{
  writeShellApplication,
  coreutils,
  gammastep,
  brightnessctl,
  mako,
  mpv,
  libnotify,
  procps,
  # soundscape stream (or a local file path). null = no sound, everything else
  # still runs; the wind-down should never depend on the network being up.
  soundUrl ? null,
  # how far down the backlight goes. dim enough to read by in the dark, not off.
  dimPercent ? 35,
}:
writeShellApplication {
  name = "cozy";
  runtimeInputs = [
    coreutils
    gammastep
    brightnessctl
    mako
    mpv
    libnotify
    procps
  ];
  text = ''
    state="''${XDG_RUNTIME_DIR:-/tmp}/cozy"
    mkdir -p "$state"

    sound_url=${if soundUrl == null then "\"\"" else "\"${soundUrl}\""}
    dim=${toString dimPercent}

    # mako suppresses everything while this mode is set, so say the soft thing
    # BEFORE going quiet or it is swallowed.
    say() { notify-send --app-name=cozy "$1" "$2" 2>/dev/null || true; }

    stop_pid() {
      [ -f "$1" ] || return 0
      kill "$(cat "$1")" 2>/dev/null || true
      rm -f "$1"
    }

    cozy_on() {
      say "cozy time" "screen's going soft, petal. i've got the rest."
      sleep 1

      # -s stashes the current level inside brightnessctl's own state, which is
      # what -r reads back on the way out.
      brightnessctl -s set "$dim%" > /dev/null

      # one long-lived gammastep in manual mode: -O is a one-shot that any later
      # gamma write would clobber, and the daemon holds the warmth until killed.
      stop_pid "$state/gammastep.pid"
      gammastep -m wayland -O 2400 > /dev/null 2>&1 &
      echo $! > "$state/gammastep.pid"

      makoctl mode -s do-not-disturb > /dev/null 2>&1 || true

      if [ -n "$sound_url" ]; then
        stop_pid "$state/sound.pid"
        mpv --no-video --loop-file=inf --volume=45 --really-quiet "$sound_url" &
        echo $! > "$state/sound.pid"
      fi

      touch "$state/on"
      echo "cozy. type 'cozy off' when you want the world back."
    }

    cozy_off() {
      stop_pid "$state/gammastep.pid"
      stop_pid "$state/sound.pid"
      # gammastep leaves the ramp where it died, so reset it by hand.
      gammastep -x > /dev/null 2>&1 || true
      brightnessctl -r > /dev/null 2>&1 || true
      makoctl mode -s default > /dev/null 2>&1 || true
      rm -f "$state/on"
      say "welcome back" "there you are. take it slow."
      echo "back to normal."
    }

    case "''${1:-on}" in
      on) cozy_on ;;
      off) cozy_off ;;
      status)
        if [ -f "$state/on" ]; then echo "cozy"; else echo "awake"; fi
        ;;
      *)
        echo "usage: cozy [on|off|status]" >&2
        exit 2
        ;;
    esac
  '';

  meta = {
    description = "Wind the desk down: warm, dim, quiet, optional soft loop";
    mainProgram = "cozy";
  };
}
