{
  writeShellApplication,
  jq,
  coreutils,
  terminal-notifier,
}:
writeShellApplication {
  name = "remind";
  runtimeInputs = [
    jq
    coreutils
    terminal-notifier
  ];
  text = ''
    # reminders that live in both worlds: laptop notifications + claude sessions.
    # store is a plain json array, off-repo, never backed up.

    mauve=$'\033[38;5;183m'; sub=$'\033[38;5;146m'; green=$'\033[38;5;151m'
    red=$'\033[38;5;210m'; yellow=$'\033[38;5;223m'; rst=$'\033[0m'
    if [ ! -t 1 ] || [ -n "''${NO_COLOR:-}" ]; then mauve=""; sub=""; green=""; red=""; yellow=""; rst=""; fi

    data_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/reminders"
    store="$data_dir/reminders.json"
    mkdir -p "$data_dir"
    [ -f "$store" ] || printf '[]\n' > "$store"

    now() { date +%s; }
    save() { tmp="$(mktemp "$data_dir/.tmp.XXXXXX")"; cat > "$tmp" && mv "$tmp" "$store"; }

    human_rel() {
      d=$(( $1 - $(now) ))
      if [ "$d" -lt 0 ]; then d=$(( -d )); pre="overdue"; else pre="in"; fi
      if   [ "$d" -lt 3600 ];  then span="$(( d / 60 ))m"
      elif [ "$d" -lt 86400 ]; then span="$(( d / 3600 ))h$(( (d % 3600) / 60 ))m"
      else span="$(( d / 86400 ))d$(( (d % 86400) / 3600 ))h"; fi
      printf '%s %s' "$pre" "$span"
    }

    cmd_add() {
      when=""; text=""
      while [ "$#" -gt 0 ]; do
        case "$1" in
          --at|-a) when="$2"; shift 2 ;;
          --in|-i) when="now + $2"; shift 2 ;;
          *) text="''${text:+$text }$1"; shift ;;
        esac
      done
      [ -n "$text" ] || { printf '%sremind: give me something to remember.%s\n' "$red" "$rst"; exit 1; }
      due=null
      if [ -n "$when" ]; then
        if ! due="$(date -d "$when" +%s 2>/dev/null)"; then
          printf '%sremind: could not read the time "%s" — try "3pm", "tomorrow 9am", or --in "30 min"%s\n' "$red" "$when" "$rst"
          exit 1
        fi
      fi
      id="$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
      jq --arg id "$id" --arg text "$text" --argjson due "$due" --argjson created "$(now)" \
        '. + [{id:$id, text:$text, due:$due, created:$created, notified:false}]' "$store" | save
      if [ "$due" = null ]; then
        printf '%s✓%s %s  %s(id %s)%s\n' "$green" "$rst" "$text" "$sub" "$id" "$rst"
      else
        printf '%s✓%s %s  %s(id %s · %s · %s)%s\n' "$green" "$rst" "$text" "$sub" "$id" "$(human_rel "$due")" "$(date -d "@$due" '+%a %H:%M')" "$rst"
      fi
    }

    cmd_ls() {
      if [ "$(jq 'length' "$store")" -eq 0 ]; then
        printf '%snothing on your plate. ✨%s\n' "$sub" "$rst"; return
      fi
      printf '%syour reminders%s\n' "$mauve" "$rst"
      jq -r 'sort_by(if .due == null then 9999999999 else .due end)[] | [.id, (.due|tostring), .text] | @tsv' "$store" \
        | while IFS="$(printf '\t')" read -r id due text; do
            if [ "$due" = null ]; then
              printf '  %s○%s %s  %s%s%s\n' "$sub" "$rst" "$text" "$sub" "$id" "$rst"
            else
              rel="$(human_rel "$due")"
              case "$rel" in overdue*) col="$red" ;; *) col="$yellow" ;; esac
              printf '  %s●%s %s  %s%s · %s%s\n' "$col" "$rst" "$text" "$sub" "$rel" "$id" "$rst"
            fi
          done
    }

    cmd_done() {
      [ -n "''${1:-}" ] || { printf '%sremind done <id>%s\n' "$red" "$rst"; exit 1; }
      before="$(jq 'length' "$store")"
      jq --arg id "$1" 'map(select(.id != $id))' "$store" | save
      if [ "$(jq 'length' "$store")" -lt "$before" ]; then
        printf '%s✓ done — one less thing. 🌸%s\n' "$green" "$rst"
      else
        printf '%sno reminder with id %s%s\n' "$sub" "$1" "$rst"
      fi
    }

    cmd_clear() { printf '[]\n' > "$store"; printf '%s✓ cleared the whole jar.%s\n' "$green" "$rst"; }

    cmd_due() {
      jq -r --argjson now "$(now)" '
        [ .[] | select(.due == null or .due <= ($now + 10800)) ]
        | sort_by(if .due == null then 9999999999 else .due end)[]
        | if   .due == null      then "STANDING\t\(.text)"
          elif .due <= $now      then "OVERDUE\t\(.text)"
          else "SOON\t\(.text)" end' "$store"
    }

    cmd_hook() {
      out="$(cmd_due)"; [ -n "$out" ] || exit 0
      printf 'azzie has active reminders. She adds them with: remind add "..." [--at "5pm"], and finishes one with: remind done <id> — you can run either for her when she asks.\n'
      printf '%s\n' "$out" | while IFS="$(printf '\t')" read -r kind text; do
        case "$kind" in
          OVERDUE)  printf -- '- OVERDUE: %s (past due — surface it warmly)\n' "$text" ;;
          SOON)     printf -- '- coming up: %s\n' "$text" ;;
          STANDING) printf -- '- standing: %s\n' "$text" ;;
        esac
      done
      printf 'Mention the overdue/soon ones if it fits the moment; never nag.\n'
    }

    cmd_notify() {
      n="$(now)"
      jq -r --argjson now "$n" '.[] | select(.due != null and .due <= $now and .notified == false) | .text' "$store" \
        | while IFS= read -r text; do
            [ -n "$text" ] || continue
            terminal-notifier -title "reminder" -message "$text" -sound Glass -appIcon "" 2>/dev/null || true
          done
      jq --argjson now "$n" 'map(if (.due != null and .due <= $now) then .notified = true else . end)' "$store" | save
    }

    case "''${1:-ls}" in
      add | a) shift; cmd_add "$@" ;;
      done | rm | d) shift; cmd_done "''${1:-}" ;;
      clear) cmd_clear ;;
      due) cmd_due ;;
      hook) cmd_hook ;;
      notify) cmd_notify ;;
      -h | --help | help)
        printf 'remind — reminders in both worlds (laptop + claude)\n'
        printf '  remind add "<text>" [--at "<when>" | --in "<dur>"]   add one\n'
        printf '  remind                                              list\n'
        printf '  remind done <id>                                    finish one\n'
        printf '  remind clear                                        wipe all\n'
        ;;
      *) cmd_ls ;;
    esac
  '';
}
