# the soft set: small comfort commands that share one data dir and one voice.
#
# grouped in ONE derivation on purpose. they are a dozen ~20-line scripts that
# all read/write ${XDG_DATA_HOME}/soft and all speak the same way; a package
# directory each would be twelve files of boilerplate around four lines of shell.
# home/modules/desktop/little.nix installs the attrset.
#
# everything user-owned (jar entries, stuffie names, moods, snacks) lives in that
# data dir, NEVER in nix: the repo is a public mirror, and it is her writing.
{
  lib,
  writeShellApplication,
  coreutils,
  gnused,
  mpv,
  libnotify,
  procps,
  systemd,
  brightnessctl,
  python3,
  fuzzel,
  wezterm,
  curl,
  asciiquarium,
  # names printed by `breathe`. no numbers: see the module option's warning.
  comfortPeople ? [ ],
  # played by `sing`. a local file or anything mpv can open; null = say so kindly.
  comfortSong ? null,
  accentHex ? "#bf7593",
}:
let
  # the accent, a dim and a reset, all of which vanish when stdout is not a
  # terminal (piped, or a systemd unit writing to the journal).
  colors = ''
    hex="${accentHex}"
    accent=$'\033[38;2;'"$((16#''${hex:1:2}));$((16#''${hex:3:2}));$((16#''${hex:5:2}))"m
    dim=$'\033[38;5;245m'
    rst=$'\033[0m'
    if [ ! -t 1 ] || [ -n "''${NO_COLOR:-}" ]; then accent=""; dim=""; rst=""; fi
    # exported so shellcheck stops calling them unused in the scripts that only
    # reach for one of the three.
    export accent dim rst
  '';

  soft =
    name: deps: body:
    writeShellApplication {
      inherit name;
      runtimeInputs = [ coreutils ] ++ deps;
      text = ''
        data="''${XDG_DATA_HOME:-$HOME/.local/share}/soft"
        mkdir -p "$data"
        ${colors}
        ${body}
      '';
      meta.mainProgram = name;
    };

  # a data file that seeds itself on first read, so no activation step has to
  # place it and azzie can edit or empty it afterwards without nix arguing.
  seed = file: lines: ''
    [ -f "$data/${file}" ] || printf '%s\n' ${
      lib.concatMapStringsSep " " (l: lib.escapeShellArg l) lines
    } > "$data/${file}"
  '';

  # what `nap` schedules. a real script rather than an inline sh -c so the store
  # path is what systemd-run gets handed, and /bin/sh never enters the picture.
  napWake = writeShellApplication {
    name = "soft-nap-wake";
    runtimeInputs = [
      brightnessctl
      libnotify
    ];
    text = ''
      brightnessctl -r > /dev/null 2>&1 || true
      notify-send --app-name=nap "time to wake up" "slowly, love. no rush."
    '';
  };
in
{
  inherit napWake;

  story = soft "story" [ ] ''
    stories=(
      "the fox had been walking all day, and when she finally sat down at the edge of the wood, the moss came up to meet her like it had been waiting. she did not have to explain where she had been. the moss did not ask. it just held the shape of her until morning."
      "there is a lamp in a window somewhere that someone leaves on for you. they do not know you. they leave it on anyway, out of habit, because someone once left one on for them. it has been passed along like that for a very long time."
      "a small bear kept a list of everything he had not finished. one night the list blew out of the window and into the river. he watched it go. in the morning he made tea, and the world had not ended, and nothing on the list had been that urgent after all."
      "the sea does not hurry. it comes all the way in, and then it goes all the way out, and it has never once been late. no one has ever asked it to try harder. it just does the next wave, and then the next one."
      "a cat found a patch of sun the size of a saucer and lay in it entirely, spilling over the edges. the sun moved. the cat moved. this was the whole of the work that day, and it was done well."
      "the little robot was built to sort things, and it sorted everything, and then one day it ran out of things to sort. it sat down. nobody came to switch it off. it turned out it was allowed to just sit, and watch the dust move in the light, and that counted as running fine."
    )
    printf '\n'
    printf '%s' "$dim"
    printf '%s\n' "''${stories[$((RANDOM % ''${#stories[@]}))]}" | fold -s -w 68 | sed 's/^/   /'
    printf '%s\n' "$rst"
    printf '   %ssleep well, petal.%s\n\n' "$accent" "$rst"
  '';

  snack = soft "snack" [ gnused ] ''
    ${seed "snacks.txt" [
      "toast with butter"
      "a banana"
      "crackers and cheese"
      "yoghurt"
      "instant noodles"
      "apple slices"
      "cereal, dry or with milk"
      "a cheese sandwich"
      "soup from a tin"
      "peanut butter on anything"
    ]}

    case "''${1:-pick}" in
      add)
        shift
        [ "$#" -gt 0 ] || { echo "usage: snack add <something easy>" >&2; exit 2; }
        printf '%s\n' "$*" >> "$data/snacks.txt"
        printf '   %sadded.%s\n' "$accent" "$rst"
        ;;
      list) sed 's/^/   /' "$data/snacks.txt" ;;
      pick)
        printf '\n   %s%s%s\n' "$accent" "$(shuf -n1 "$data/snacks.txt")" "$rst"
        printf '   %sthat one. you do not have to decide anything else.%s\n\n' "$dim" "$rst"
        ;;
      *) echo "usage: snack [pick|add <thing>|list]" >&2; exit 2 ;;
    esac
  '';

  jar = soft "jar" [ gnused ] ''
    file="$data/jar.txt"
    touch "$file"

    case "''${1:-read}" in
      add)
        shift
        [ "$#" -gt 0 ] || { echo "usage: jar add <the nice thing>" >&2; exit 2; }
        printf '%s\n' "$*" >> "$file"
        printf '   %sin the jar.%s\n' "$accent" "$rst"
        ;;
      list) sed 's/^/   /' "$file" ;;
      read)
        if [ ! -s "$file" ]; then
          printf '\n   %sthe jar is empty. put something in it: jar add "..."%s\n\n' "$dim" "$rst"
          exit 0
        fi
        printf '\n   %s%s%s\n\n' "$accent" "$(shuf -n1 "$file")" "$rst"
        ;;
      *) echo "usage: jar [read|add <thing>|list]" >&2; exit 2 ;;
    esac
  '';

  plushies = soft "plushies" [ gnused ] ''
    file="$data/plushies.txt"
    touch "$file"

    case "''${1:-today}" in
      add)
        shift
        [ "$#" -gt 0 ] || { echo "usage: plushies add <name>" >&2; exit 2; }
        printf '%s\n' "$*" >> "$file"
        printf '   %s%s is on the list.%s\n' "$accent" "$*" "$rst"
        ;;
      list) sed 's/^/   /' "$file" ;;
      today)
        if [ ! -s "$file" ]; then
          printf '\n   %sno stuffies yet. plushies add <name>%s\n\n' "$dim" "$rst"
          exit 0
        fi
        # seeded by the date, so the same one is picked all day and someone new
        # comes round tomorrow.
        pick="$(shuf -n1 --random-source=<(yes "$(date +%Y%m%d)") "$file")"
        printf '\n   %stoday: %s%s%s\n' "$dim" "$accent" "$pick" "$rst"
        printf '   %sgo and get them.%s\n\n' "$dim" "$rst"
        ;;
      *) echo "usage: plushies [today|add <name>|list]" >&2; exit 2 ;;
    esac
  '';

  mood = soft "mood" [ ] ''
    file="$data/mood.log"
    touch "$file"

    if [ "$#" -eq 0 ]; then
      if [ ! -s "$file" ]; then
        printf '\n   %snothing logged yet. mood <a word>%s\n\n' "$dim" "$rst"
        exit 0
      fi
      printf '\n'
      tail -n 7 "$file" | while read -r l; do printf '   %s%s%s\n' "$dim" "$l" "$rst"; done
      printf '\n'
      exit 0
    fi

    printf '%s  %s\n' "$(date +%Y-%m-%d)" "$*" >> "$file"
    printf '   %skept. no notes, no follow-up.%s\n' "$dim" "$rst"
  '';

  # `breathe`, NOT `panic`: nushell ships a builtin `panic` that deliberately
  # crashes the shell, and a builtin always wins over a binary on PATH.
  breathe = soft "breathe" [ ] ''
    printf '\n   %syou are not in danger right now. this is a feeling, and it passes.%s\n\n' "$accent" "$rst"
    printf '   %sbreathe:%s in for 4, hold for 7, out for 8. three times.\n\n' "$accent" "$rst"
    printf '   %sname:%s 5 things you see. 4 you can touch. 3 you hear.\n' "$accent" "$rst"
    printf '         2 you smell. 1 you taste.\n\n'
    printf '   %sfeet on the floor. back against something solid.%s\n\n' "$dim" "$rst"
    ${
      if comfortPeople == [ ] then
        ''printf '   %syour people are one message away.%s\n\n' "$dim" "$rst"''
      else
        ''
          printf '   %speople who would want to hear from you:%s\n' "$accent" "$rst"
          printf '   %s%s%s\n\n' "$dim" ${lib.escapeShellArg (lib.concatStringsSep ", " comfortPeople)} "$rst"
          printf '   %spick one. you do not have to explain it well.%s\n\n' "$dim" "$rst"
        ''
    }
  '';

  pop = soft "pop" [ ] ''
    rows=6
    cols=14
    left=$((rows * cols))
    declare -A popped

    draw() {
      clear
      printf '\n   %sany key pops one. q to stop.%s\n\n' "$dim" "$rst"
      for r in $(seq 1 $rows); do
        printf '   '
        for c in $(seq 1 $cols); do
          if [ -n "''${popped[$r.$c]:-}" ]; then
            printf '%s . %s' "$dim" "$rst"
          else
            printf '%s(o)%s' "$accent" "$rst"
          fi
        done
        printf '\n'
      done
      printf '\n   %s%d left%s\n' "$dim" "$left" "$rst"
    }

    draw
    while [ "$left" -gt 0 ]; do
      read -rsn1 key || break
      [ "$key" = q ] && break
      r=$((RANDOM % rows + 1)); c=$((RANDOM % cols + 1))
      while [ -n "''${popped[$r.$c]:-}" ]; do
        r=$((RANDOM % rows + 1)); c=$((RANDOM % cols + 1))
      done
      popped[$r.$c]=1
      left=$((left - 1))
      draw
    done
    printf '\n   %sall done.%s\n\n' "$accent" "$rst"
  '';

  # every url below was checked live; the somafm ones answer on ice1, their
  # /name.mp3 shortcuts 404. anything in ~/Music/cozy/<name>* wins over the
  # stream, so a local file can replace one that ever goes dark.
  sounds =
    soft "sounds"
      [
        mpv
        procps
      ]
      ''
        pidfile="''${XDG_RUNTIME_DIR:-/tmp}/soft-sounds.pid"
        localdir="$HOME/Music/cozy"

        declare -A streams=(
          [sleep]="http://radio.stereoscenic.com/asp-h"
          [ambient]="http://radio.stereoscenic.com/ama-h"
          [celestial]="http://radio.stereoscenic.com/cel-h"
          [drone]="https://ice1.somafm.com/dronezone-128-mp3"
          [space]="https://ice1.somafm.com/deepspaceone-128-mp3"
          [chill]="https://ice1.somafm.com/groovesalad-128-mp3"
        )

        stop() {
          [ -f "$pidfile" ] || return 0
          kill "$(cat "$pidfile")" 2>/dev/null || true
          rm -f "$pidfile"
        }

        case "''${1:-list}" in
          off|stop)
            stop
            printf '   %squiet again.%s\n' "$dim" "$rst"
            ;;
          list)
            printf '\n   %ssounds:%s %s\n' "$accent" "$rst" "''${!streams[*]}"
            if [ -d "$localdir" ]; then
              printf '   %syour own files in %s are used first.%s\n' "$dim" "$localdir" "$rst"
            fi
            printf '   %ssounds <name> to play, sounds off to stop.%s\n\n' "$dim" "$rst"
            ;;
          *)
            what="$1"
            src=""
            if [ -d "$localdir" ]; then
              src="$(find "$localdir" -maxdepth 1 -iname "$what*" -type f | head -n1)"
            fi
            [ -n "$src" ] || src="''${streams[$what]:-}"
            if [ -z "$src" ]; then
              printf '   %sdo not know that one. try: %s%s\n' "$dim" "''${!streams[*]}" "$rst"
              exit 2
            fi
            stop
            mpv --no-video --loop-playlist=inf --volume=45 --really-quiet "$src" &
            echo $! > "$pidfile"
            printf '   %s%s, playing. sounds off when you have had enough.%s\n' "$accent" "$what" "$rst"
            ;;
        esac
      '';

  sing = soft "sing" [ mpv ] (
    if comfortSong == null then
      ''
        printf '\n   %sno comfort song set yet.%s\n' "$dim" "$rst"
        printf '   %sput one in rice.little.comfortSong (a file path or a url).%s\n\n' "$dim" "$rst"
      ''
    else
      ''
        printf '   %splaying your song.%s\n' "$accent" "$rst"
        exec mpv --no-video --really-quiet ${lib.escapeShellArg comfortSong}
      ''
  );

  nap =
    soft "nap"
      [
        systemd
        brightnessctl
      ]
      ''
        mins="''${1:-20}"
        case "$mins" in
          *[!0-9]* | "") echo "usage: nap [minutes]" >&2; exit 2 ;;
          *) ;;
        esac

        brightnessctl -s set 10% > /dev/null

        # systemd-run, not a backgrounded sleep: the wake has to survive this
        # terminal closing, which is the normal way a nap starts.
        systemd-run --user --quiet --collect --on-active="''${mins}m" \
          --unit=soft-nap-wake ${lib.getExe napWake}

        printf '\n   %s%s minutes. i will wake you softly.%s\n\n' "$accent" "$mins" "$rst"
      '';

  # `cozy`, `sounds`, `story` and `meds-taken` are called by NAME below, not by
  # store path: they are installed alongside these by the same module, and going
  # through PATH keeps the evening scripts from pinning a stale copy of each
  # other every time one of them changes.
  tuck =
    soft "tuck"
      [
        systemd
        libnotify
      ]
      ''
        wake="''${1:-}"

        printf '\n   %stucking you in.%s\n\n' "$accent" "$rst"
        cozy on > /dev/null || true
        sounds sleep > /dev/null 2>&1 || true
        story || true

        if [ -n "$wake" ]; then
          case "$wake" in
            [0-2][0-9]:[0-5][0-9]) ;;
            *) echo "   (that time looked odd, so no alarm was set. try: tuck 08:30)" >&2; wake="" ;;
          esac
        fi

        if [ -n "$wake" ]; then
          systemd-run --user --quiet --collect --unit=soft-alarm \
            --on-calendar="*-*-* $wake:00" ${lib.getExe napWake}
          printf '   %salarm set for %s. goodnight, petal.%s\n\n' "$dim" "$wake" "$rst"
        else
          printf '   %sno alarm. sleep as long as you like.%s\n\n' "$dim" "$rst"
        fi
      '';

  bedtime = soft "bedtime" [ ] ''
    steps=(
      "teeth brushed?"
      "glass of water by the bed?"
      "meds taken?"
      "laptop on the charger?"
      "phone somewhere you can reach it?"
      "something soft to hold?"
    )

    printf '\n   %sbedtime, love. one at a time.%s\n\n' "$accent" "$rst"
    for s in "''${steps[@]}"; do
      printf '   %s%s%s ' "$dim" "$s" "$rst"
      read -r _ || true
      printf '   %s  good.%s\n' "$accent" "$rst"
    done
    printf '\n   %sthat is everything. type tuck when you are ready.%s\n\n' "$dim" "$rst"
  '';

  sleepy = soft "sleepy" [ brightnessctl ] ''
    # deeper than cozy: cozy is for winding down, this is for actually going.
    # NOT greyscale, niri has no runtime saturation control and faking it with a
    # gamma ramp only tints, so this leans on dark + warm + quiet instead.
    cozy on > /dev/null || true
    brightnessctl set 8% > /dev/null
    sounds sleep > /dev/null 2>&1 || true
    printf '\n   %severything is off but the quiet. type cozy off when you surface.%s\n\n' "$dim" "$rst"
  '';

  # a colouring page generator: concentric rings of petals, black outline on
  # white, saved as SVG so it scales to any paper or canvas size.
  colouring = soft "colouring" [ python3 ] ''
        out="$HOME/Pictures/colouring"
        mkdir -p "$out"
        file="$out/mandala-$(date +%Y%m%d-%H%M%S).svg"

        OUT="$file" python3 <<'PY'
    import math, os, random

    W = 1000
    C = W / 2
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">' % (W, W, W, W)]
    parts.append('<rect width="100%" height="100%" fill="white"/>')
    parts.append('<g fill="none" stroke="black" stroke-width="3" stroke-linejoin="round">')

    rings = random.randint(4, 6)
    radius = 60
    for ring in range(rings):
        petals = random.choice([6, 8, 10, 12])
        size = random.uniform(35, 70)
        for i in range(petals):
            a = 2 * math.pi * i / petals
            x = C + radius * math.cos(a)
            y = C + radius * math.sin(a)
            shape = random.choice(['circle', 'petal', 'diamond'])
            if shape == 'circle':
                parts.append('<circle cx="%.1f" cy="%.1f" r="%.1f"/>' % (x, y, size / 2))
            elif shape == 'diamond':
                parts.append('<polygon points="%.1f,%.1f %.1f,%.1f %.1f,%.1f %.1f,%.1f"/>'
                             % (x, y - size / 2, x + size / 2, y, x, y + size / 2, x - size / 2, y))
            else:
                d = size / 2
                parts.append('<path d="M %.1f %.1f q %.1f %.1f 0 %.1f q %.1f %.1f 0 %.1f Z" '
                             'transform="rotate(%.1f %.1f %.1f)"/>'
                             % (x, y - d, d, d, 2 * d, -d, -d, -2 * d, math.degrees(a), x, y))
        parts.append('<circle cx="%.1f" cy="%.1f" r="%.1f"/>' % (C, C, radius))
        radius += random.uniform(70, 100)

    parts.append('<circle cx="%.1f" cy="%.1f" r="28"/>' % (C, C))
    parts.append('</g></svg>')
    open(os.environ['OUT'], 'w').write('\n'.join(parts))
    PY

        printf '\n   %sa new page to colour in:%s\n' "$accent" "$rst"
        printf '   %s%s%s\n\n' "$dim" "$file" "$rst"
  '';

  # the picker. every entry is a command from this set, run in a floating
  # terminal that waits for a keypress before closing, so a one-shot like `hug`
  # does not flash past. niri.nix floats anything with the comfort.float app-id.
  comfort =
    soft "comfort"
      [
        fuzzel
        wezterm
        gnused
      ]
      ''
        menu="hug
        story
        jar
        plushies
        snack
        breathe
        pop
        colouring
        mood
        bedtime
        sleepy
        sounds sleep
        sounds off
        sip
        meds-taken"

        pick="$(printf '%s\n' "$menu" | sed 's/^ *//' | fuzzel --dmenu --prompt 'comfort ')"
        [ -n "$pick" ] || exit 0

        exec wezterm start --class comfort.float -- \
          bash -lc "$pick; printf '\n   press any key\n'; read -rsn1"
      '';

  # the card. `morning --notify` is what the timer fires; typed bare it prints.
  morning =
    soft "morning"
      [
        curl
        libnotify
      ]
      ''
        # wttr.in locates by ip, which is the right answer for a laptop that travels.
        # two seconds and one retry, then it simply says nothing about the weather.
        weather="$(curl -fsS --max-time 2 --retry 1 'https://wttr.in/?format=%C,+%t' 2>/dev/null || true)"

        meds="''${XDG_RUNTIME_DIR:-/tmp}/care-meds-pending"
        jar_file="$data/jar.txt"
        plush_file="$data/plushies.txt"

        lines=()
        [ -n "$weather" ] && lines+=("outside: $weather")
        [ -f "$meds" ] && lines+=("meds are still waiting.")
        if [ -s "$plush_file" ]; then
          lines+=("today's stuffie: $(shuf -n1 --random-source=<(yes "$(date +%Y%m%d)") "$plush_file")")
        fi
        [ -s "$jar_file" ] && lines+=("from the jar: $(shuf -n1 "$jar_file")")
        lines+=("nothing is urgent yet. start with something small.")

        if [ "''${1:-}" = --notify ]; then
          notify-send --app-name=morning "good morning, petal" "$(printf '%s\n' "''${lines[@]}")"
          exit 0
        fi

        printf '\n   %sgood morning, petal.%s\n\n' "$accent" "$rst"
        printf "   $dim%s$rst\n" "''${lines[@]}"
        printf '\n'
      '';

  # idle fish. explicitly NOT a lock: azzie's call is that locking stays manual
  # (Mod+Alt+L), so this only ever draws over the screen and dies on resume.
  screensaver =
    soft "screensaver"
      [
        wezterm
        asciiquarium
        procps
      ]
      ''
        pidfile="''${XDG_RUNTIME_DIR:-/tmp}/soft-screensaver.pid"

        case "''${1:-start}" in
          start)
            if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then exit 0; fi
            wezterm start --class screensaver -- asciiquarium &
            echo $! > "$pidfile"
            ;;
          stop)
            [ -f "$pidfile" ] || exit 0
            kill "$(cat "$pidfile")" 2>/dev/null || true
            rm -f "$pidfile"
            ;;
          *) echo "usage: screensaver [start|stop]" >&2; exit 2 ;;
        esac
      '';

  screentime =
    soft "screentime"
      [
        systemd
        libnotify
      ]
      ''
        # session start, not machine uptime: a laptop that slept all night has not
        # been stared at all night.
        stamp="$(loginctl show-session "''${XDG_SESSION_ID:-self}" -p Timestamp --value 2>/dev/null || true)"
        [ -n "$stamp" ] || exit 0
        start="$(date -d "$stamp" +%s 2>/dev/null || true)"
        [ -n "$start" ] || exit 0

        hours=$(( ( $(date +%s) - start ) / 3600 ))
        [ "$hours" -ge "''${SOFT_SCREENTIME_HOURS:-6}" ] || exit 0
        notify-send --app-name=care "you've been up a while" \
          "$hours hours at this screen, love. stand up for a minute?"
      '';
}
