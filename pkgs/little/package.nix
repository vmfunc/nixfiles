# `little` / `big`: flip the desk into little mode and back.
#
# everything it touches is a RUNTIME knob, never a config file: niri output scale
# via `niri msg`, a spawned kitty, a warm gamma. that way it needs no rebuild, and
# `big` puts it back exactly (the pre-flip scale per output is saved, not assumed,
# because outputs differ and 1.0 is a bad guess on a hidpi panel).
#
# `niri` is deliberately NOT in runtimeInputs: the CLI speaks an IPC schema that
# has to match the RUNNING compositor, and pinning it here pins the store's
# version instead. between a rebuild and a niri restart those differ and every
# call dies with "missing field ...". the session's own niri is on PATH and is
# by definition the right one.
{
  writeShellApplication,
  coreutils,
  jq,
  wlsunset,
  libnotify,
  procps,
  oneko,
  scale ? 1.6,
}:
writeShellApplication {
  name = "little";
  runtimeInputs = [
    coreutils
    jq
    wlsunset
    libnotify
    procps
    oneko
  ];
  text = ''
    state="''${XDG_RUNTIME_DIR:-/tmp}/little"
    mkdir -p "$state"

    little_on() {
      # save every output's current scale before touching any of them.
      niri msg --json outputs | jq -r 'to_entries[] | "\(.key) \(.value.logical.scale)"' \
        > "$state/scales"

      while read -r name _; do
        [ -n "$name" ] || continue
        niri msg output "$name" scale ${toString scale} > /dev/null
      done < "$state/scales"

      # a gentle warm cast, nowhere near cozy's 2400K: this is daytime soft.
      # wlsunset rather than `gammastep -O`, which exits instantly on wayland and
      # takes its own gamma with it. near-equal -T/-t pins one temperature.
      if [ -f "$state/warm.pid" ]; then
        kill "$(cat "$state/warm.pid")" 2>/dev/null || true
      fi
      wlsunset -T 4501 -t 4500 -S 00:01 -s 23:59 > /dev/null 2>&1 &
      echo $! > "$state/warm.pid"

      # by pid, not pkill: an oneko azzie started herself should survive `big`.
      if [ ! -f "$state/oneko.pid" ] || ! kill -0 "$(cat "$state/oneko.pid")" 2>/dev/null; then
        oneko -tora > /dev/null 2>&1 &
        echo $! > "$state/oneko.pid"
      fi

      touch "$state/on"
      notify-send --app-name=little "little mode" "everything's bigger and softer now. type 'big' when you want to grow up again."
      echo "little mode on. type 'big' to go back."
    }

    little_off() {
      if [ -f "$state/scales" ]; then
        while read -r name old; do
          [ -n "$name" ] || continue
          niri msg output "$name" scale "$old" > /dev/null
        done < "$state/scales"
        rm -f "$state/scales"
      fi

      # killing the client IS the gamma reset: wlr-gamma-control hands the ramp
      # back to the compositor on disconnect.
      if [ -f "$state/warm.pid" ]; then
        kill "$(cat "$state/warm.pid")" 2>/dev/null || true
        rm -f "$state/warm.pid"
      fi

      if [ -f "$state/oneko.pid" ]; then
        kill "$(cat "$state/oneko.pid")" 2>/dev/null || true
        rm -f "$state/oneko.pid"
      fi

      rm -f "$state/on"
      notify-send --app-name=little "all grown up" "back to normal. i'm still here."
      echo "back to normal."
    }

    case "''${1:-on}" in
      on) little_on ;;
      off) little_off ;;
      status)
        if [ -f "$state/on" ]; then echo "little"; else echo "big"; fi
        ;;
      *)
        echo "usage: little [on|off|status]" >&2
        exit 2
        ;;
    esac
  '';

  meta = {
    description = "Flip the desk into little mode (bigger, softer) and back";
    mainProgram = "little";
  };
}
