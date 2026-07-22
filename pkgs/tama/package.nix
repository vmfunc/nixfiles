# tama: a tamagotchi that lives in the terminal, wired flavor. state persists in
# XDG_STATE_HOME and decays in real time (hunger ~4h/step, loneliness ~6h/step),
# so she is genuinely different after a weekend away. she never dies, at zero she
# drifts into static until fed. cozy-CLI family (case/plan/mesh): pure
# writeShellApplication, portable darwin + linux, no daemon, no network.
{
  writeShellApplication,
  coreutils,
  jq,
}:
writeShellApplication {
  name = "tama";

  runtimeInputs = [
    coreutils
    jq
  ];

  text = ''
    mauve=$'\033[38;5;183m'
    subtext=$'\033[38;5;146m'
    green=$'\033[38;5;151m'
    red=$'\033[38;5;174m'
    reset=$'\033[0m'

    STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/tama"
    STATE="$STATE_DIR/state.json"
    now="$(date +%s)"

    # decay steps: one heart of hunger per 4h unfed, one of mood per 6h unloved
    HUNGER_STEP=14400
    MOOD_STEP=21600

    if [ ! -f "$STATE" ]; then
      mkdir -p "$STATE_DIR"
      jq -n --argjson t "$now" \
        '{name: "tama", born: $t, fed: $t, pet: $t, play: $t}' > "$STATE"
      printf '%s. o O ( something hatched in the wired )%s\n' "$mauve" "$reset"
    fi

    name="$(jq -r .name "$STATE")"
    fed="$(jq -r .fed "$STATE")"
    pet="$(jq -r .pet "$STATE")"
    play="$(jq -r .play "$STATE")"

    stamp() { # $1 = json key to refresh to now
      tmp="$(mktemp "$STATE_DIR/.state.XXXXXX")"
      jq --arg k "$1" --argjson t "$now" '.[$k] = $t' "$STATE" > "$tmp"
      mv "$tmp" "$STATE"
    }

    lvl() { # $1 = last-seen epoch, $2 = step seconds -> 0..5 hearts remaining
      age=$(( now - $1 )); dec=$(( age / $2 ))
      [ "$dec" -gt 5 ] && dec=5
      echo $(( 5 - dec ))
    }

    bar() { # $1 = level -> [♥♥♥♡♡] in accent/dim
      out=""
      for i in 1 2 3 4 5; do
        if [ "$i" -le "$1" ]; then out="$out$mauve♥"; else out="$out$subtext♡"; fi
      done
      printf '%s%s' "$out" "$reset"
    }

    status() {
      fed_lvl="$(lvl "$fed" "$HUNGER_STEP")"
      recent="$pet"; [ "$play" -gt "$pet" ] && recent="$play"
      mood_lvl="$(lvl "$recent" "$MOOD_STEP")"
      low="$fed_lvl"; [ "$mood_lvl" -lt "$low" ] && low="$mood_lvl"

      case "$low" in
        5|4) face="(^‿^)";   line="she hums along with the wired." ;;
        3)   face="(･ω･)";   line="present day... present time. she waits." ;;
        2)   face="(´･_･\`)"; line="she keeps checking the door of the wired." ;;
        1)   face="(｡•́︿•̀｡)"; line="signal weak. she misses you." ;;
        *)   face="▓▒░_░▒▓"; line="she has drifted into static. feed her." ;;
      esac
      col="$green"; [ "$low" -le 2 ] && col="$red"

      printf '\n  %s%s%s  %s%s%s\n' "$col" "$face" "$reset" "$mauve" "$name" "$reset"
      printf '  %sFED:%s  %s\n' "$subtext" "$reset" "$(bar "$fed_lvl")"
      printf '  %sMOOD:%s %s\n' "$subtext" "$reset" "$(bar "$mood_lvl")"
      printf '  %s"%s"%s\n\n' "$subtext" "$line" "$reset"
    }

    case "''${1:-}" in
      "")   status ;;
      feed) stamp fed;  printf '%s%s munches happily. (^‿^)%s\n' "$green" "$name" "$reset" ;;
      pet)  stamp pet;  printf '%s%s leans into your hand.%s\n' "$green" "$name" "$reset" ;;
      play) stamp play; printf '%syou and %s watch the wired scroll by.%s\n' "$green" "$name" "$reset" ;;
      name)
        [ -n "''${2:-}" ] || { printf 'usage: tama name <newname>\n' >&2; exit 1; }
        tmp="$(mktemp "$STATE_DIR/.state.XXXXXX")"
        jq --arg n "$2" '.name = $n' "$STATE" > "$tmp"; mv "$tmp" "$STATE"
        printf '%sshe answers to %s now.%s\n' "$mauve" "$2" "$reset" ;;
      help|-h|--help)
        printf 'tama: a small creature in the wired\n'
        printf '  tama          how is she doing\n'
        printf '  tama feed     one heart of food (decays ~4h/heart)\n'
        printf '  tama pet      affection (mood decays ~6h/heart)\n'
        printf '  tama play     watch the wired together (also mood)\n'
        printf '  tama name <n> rename her\n' ;;
      *) printf 'tama: unknown command %s (try: tama help)\n' "$1" >&2; exit 1 ;;
    esac
  '';
}
