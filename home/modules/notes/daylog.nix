# rice.daylog: the `daylog` command. opens claude code on today's daily note
# with the /daily-log skill already pointed at it, so "what did i actually do
# today" is one word instead of a prompt she has to retype every evening.
# `-n/--night` runs /wind-down instead (log + tidy plan + hand to cozy).
# also ships `daylog-harvest`, the deterministic source-gatherer the skill
# runs: harvesting moved here from skill-inlined recipes so its toolchain
# (sqlite3 for zen history, jq for transcripts) is closure-pinned instead of
# hoped-for on PATH. the skill keeps the editorial half.
#
# it also resolves a coarse ip-based location and passes it in the prompt, the
# interim answer to "where have i been today" until the phone-side source lands
# (see the daily-log-harvest project). fail-soft: a bad/absent lookup passes no
# location rather than a wrong one, since this feeds a synced diary.
#
# cross-file deps:
#   - the skills live in the private claude-config bundle and are wired to
#     ~/.claude/skills/{daily-log,wind-down} by home/modules/cli/claude.nix.
#     this module only supplies the launcher; ALL behaviour (what gets
#     harvested, the per-host [!log] callout that lets every laptop append to
#     the same synced note, the rule that the "one honest line" stays hers) is
#     the skill's, so it can be changed without a rebuild here.
#   - the vault (rice.notes, notes/obsidian.nix) holds daily/<date>.md. default
#     path mirrors that module's default rather than reading its option, so this
#     stays evaluable on hosts that never import the notes spine (same trick as
#     cli/wired.nix).
#   - `plan` (pkgs/plan) and the repos under ~/Projects are read by the skill as
#     harvest sources; nothing here needs them at build time.
#
# claude-code is resolved from PATH, NOT put in the closure: it ships in the
# system layer on linux (modules/nixos/apps.nix) and would come from homebrew on
# the macs, so a runtimeInputs dependency would either duplicate it or fail to
# eval on darwin. missing binary is a clear error, not a stack trace.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.daylog;

  # daylog-harvest: the deterministic half of /daily-log. gathers every machine
  # source for one day (all claude sessions with their prompts, git across the
  # repo roots, zen browser history, atuin shell activity, the care water count,
  # candidate photos from the nextcloud sync, plan, vault files touched) and
  # prints one markdown report the skill edits down. exists because the skill used to
  # shell out to bare `sqlite3`/`jq` recipes, and sqlite3 is not on PATH on the
  # linux boxes, so the browser leg silently died every night. here the whole
  # toolchain is closure-pinned. output is context for an editor, not the
  # diary itself; the skill's editorial rules still decide what survives.
  daylogHarvest = pkgs.writeShellApplication {
    name = "daylog-harvest";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.jq
      pkgs.sqlite
      pkgs.git
      # weather one-liner only; every other leg stays offline
      pkgs.curl
      pkgs.gawk # battery-span folding
      pkgs.exiftool # gps off the day's photos
      pkgs.tesseract # screenshot ocr (wording hints, never quoted)
      pkgs.systemd # journalctl for the notification leg
      pkgs.networkmanager # nmcli, networks joined today
    ];
    text = ''
      day="''${1:-$(date +%F)}"
      case "$day" in
        [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
        *) echo "usage: daylog-harvest [YYYY-MM-DD]" >&2; exit 1 ;;
      esac
      start=$(date -d "$day 00:00" +%s)
      end=$((start + 86400))
      next=$(date -d "$day + 1 day" +%F)

      echo "# daylog harvest for $day on $(uname -n)"

      # one line of sky, network fail-soft: a dead lookup prints nothing rather
      # than stalling the harvest or inventing weather for the diary.
      wx=$(curl -fsS --max-time 4 'https://wttr.in/?format=3' 2>/dev/null || true)
      [ -z "$wx" ] || printf '\n%s\n' "☀ $wx"

      # every transcript that has at least one message from the day, one section
      # per session: title, project, active window, then the user prompts. the
      # `?`-guards matter: transcript lines are heterogeneous and a missing key
      # must select-away, not error. `|| true` everywhere `head` closes a pipe,
      # or pipefail turns SIGPIPE into a dead harvest.
      echo
      echo "## claude sessions (all of today's)"
      for f in "$HOME"/.claude/projects/*/*.jsonl; do
        [ -e "$f" ] || continue
        grep -q "\"timestamp\":\"$day" "$f" 2>/dev/null || continue
        title=$(jq -r 'select(.type?=="summary") | .summary // .aiTitle // empty' "$f" \
          2>/dev/null | tail -1 || true)
        cwd=$(jq -r 'select(.cwd?) | .cwd' "$f" 2>/dev/null | head -1 || true)
        span=$(jq -r --arg d "$day" \
          'select(.timestamp? // "" | startswith($d)) | .timestamp' "$f" 2>/dev/null \
          | sort | sed -n '1p;$p' | cut -c12-16 | paste -sd- - || true)
        echo
        echo "### ''${title:-untitled} [''${cwd:-?}] $span"
        # drop harness noise (interrupt markers, task-notification / caveat xml
        # blocks and their continuation lines) and adjacent duplicates from
        # session resumes, so the prompts read as what she actually said.
        jq -r --arg d "$day" '
          select(.type?=="user" and (.timestamp? // "" | startswith($d))
                 and (.message.content | type=="string"))
          | .message.content' "$f" 2>/dev/null \
          | grep -v -e '^\[Request interrupted' -e '^<' -e '^\[SYSTEM' \
          | cut -c1-160 | uniq | head -12 \
          | sed 's/^/- /' || true
      done

      # the prompt index catches anything the per-session sweep missed
      echo
      echo "## claude prompt index"
      if [ -e "$HOME/.claude/history.jsonl" ]; then
        jq -r --argjson s "$start" --argjson e "$end" '
          select((.timestamp? // 0) / 1000 >= $s and (.timestamp? // 0) / 1000 < $e)
          | "- [\(.project? // "?")] \(.display? // "")"' \
          "$HOME/.claude/history.jsonl" 2>/dev/null | cut -c1-160 | head -40 || true
      fi

      echo
      echo "## git"
      for repo in "$HOME/nixfiles" "$HOME/plan" "$HOME"/Projects/* "$HOME"/workspace/*; do
        [ -d "$repo/.git" ] || continue
        log=$(git -C "$repo" log --since="$day 00:00" --until="$day 23:59:59" \
          --pretty='%h %s' 2>/dev/null || true)
        dirty=$(git -C "$repo" status --short 2>/dev/null | head -8 || true)
        { [ -n "$log" ] || [ -n "$dirty" ]; } || continue
        echo
        echo "### ''${repo#"$HOME"/}"
        [ -z "$log" ] || printf '%s\n' "$log" | sed 's/^/- /'
        [ -z "$dirty" ] || { echo "- uncommitted:"; printf '%s\n' "$dirty" | sed 's/^/    /'; }
      done

      # zen holds a lock on places.sqlite, so query a copy (wal too, or the
      # freshest visits are missing). visit_date is epoch MICROseconds; the
      # boundary math stays in shell where it is integers all the way down.
      echo
      echo "## browser (zen, top urls today)"
      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT
      found=0
      for db in "$HOME"/.zen/*/places.sqlite "$HOME"/.config/zen/*/places.sqlite; do
        [ -e "$db" ] || continue
        found=1
        cp -f "$db" "$tmp/places.sqlite"
        [ ! -e "$db-wal" ] || cp -f "$db-wal" "$tmp/places.sqlite-wal"
        sqlite3 -separator ' | ' "$tmp/places.sqlite" \
          "SELECT count(*), coalesce(nullif(p.title,'''), p.url), p.url
           FROM moz_historyvisits v JOIN moz_places p ON p.id = v.place_id
           WHERE v.visit_date >= $start*1000000 AND v.visit_date < $end*1000000
           GROUP BY p.url ORDER BY count(*) DESC LIMIT 40;" 2>/dev/null \
          | sed 's/^/- /' || true
      done
      [ "$found" -eq 1 ] || echo "(no zen profile found)"

      echo
      echo "## plan"
      if command -v plan >/dev/null 2>&1; then
        # strip the ansi color plan paints for terminals; this lands in markdown
        plan 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | head -30 || true
      else
        echo "(plan not on PATH)"
      fi

      # what the hands did: atuin's history, queried straight off a COPY of its
      # sqlite (atuin's cli refuses to run without the shell session env, the db
      # does not care). timestamps are epoch nanoseconds.
      echo
      echo "## shell activity (atuin)"
      adb="$HOME/.local/share/atuin/history.db"
      if [ -e "$adb" ]; then
        cp -f "$adb" "$tmp/history.db" 2>/dev/null || true
        echo "top dirs:"
        sqlite3 -separator ' | ' "$tmp/history.db" \
          "SELECT count(*), cwd FROM history
           WHERE timestamp/1000000000 >= $start AND timestamp/1000000000 < $end
           GROUP BY cwd ORDER BY count(*) DESC LIMIT 10;" 2>/dev/null \
          | sed 's/^/- /' || true
        # 'cccc%' drops yubikey OTP mashes typed into a terminal by accident;
        # single-use or not, they have no business in a synced diary draft.
        echo "top commands:"
        sqlite3 -separator ' | ' "$tmp/history.db" \
          "SELECT count(*), substr(command,1,instr(command||' ',' ')-1) w FROM history
           WHERE timestamp/1000000000 >= $start AND timestamp/1000000000 < $end
           AND command NOT LIKE 'cccc%'
           GROUP BY w ORDER BY count(*) DESC LIMIT 12;" 2>/dev/null \
          | sed 's/^/- /' || true
      else
        echo "(no atuin db)"
      fi

      # the care trail: rice.care's water nudge counts glasses into a per-day
      # file. meds keep only a volatile pending marker, so no meds line here.
      echo
      echo "## care"
      soft="''${XDG_DATA_HOME:-$HOME/.local/share}/soft"
      if [ -e "$soft/water-$day" ]; then
        echo "- water: $(cat "$soft/water-$day") glasses"
      else
        echo "- water: no count for $day"
      fi
      for k in meds food; do
        if [ -e "$soft/$k-$day" ]; then
          echo "- $k: $(paste -sd', ' "$soft/$k-$day")"
        fi
      done
      # little/hug are hers and private by default: presence only, no times, and
      # the skill only writes a line if she has opted in (see the skill).
      if [ -e "$soft/little-$day" ]; then
        echo "- little: yes (private, skill decides)"
      fi

      # candidate photos for the day, by mtime window: the nextcloud client
      # preserves original file mtime, so a shot taken today lands with today's
      # stamp and an old photo synced today stays excluded. the SKILL views
      # these and picks; this only lists. screenshots land here too on purpose,
      # they are evidence of the day even when they lose the editorial cut.
      echo
      echo "## photos (candidates, skill picks)"
      for root in "$HOME/Nextcloud" "$HOME/Pictures"; do
        [ -d "$root" ] || continue
        find "$root" -type f \
          \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
             -o -iname '*.heic' -o -iname '*.webp' -o -iname '*.dng' \) \
          -newermt "$day 00:00" ! -newermt "$next 00:00" \
          -printf '%p\t%TH:%TM\t%s\n' 2>/dev/null || true
      done | head -60 | while IFS="$(printf '\t')" read -r p t sz; do
        # exif gps where the phone recorded it: real coordinates beat the ip
        # guess, and a photo without them just prints no place.
        gps=$(exiftool -s3 -n -c '%.4f' -GPSPosition "$p" 2>/dev/null | head -1 || true)
        echo "- $p ($t, $sz bytes)''${gps:+ @ $gps}"
      done

      # the shape of the day, not a productivity metric: first and last thing
      # touched, and the long quiet gaps between them (>90min of no commands).
      # the sleep estimate is the gap ACROSS midnight, so it is honest about a
      # 4am night and simply absent when the db has nothing to say.
      echo
      echo "## day shape"
      if [ -e "$tmp/history.db" ]; then
        sqlite3 "$tmp/history.db" \
          "SELECT 'first: ' || time(timestamp/1000000000,'unixepoch','localtime')
           FROM history WHERE timestamp/1000000000 >= $start AND timestamp/1000000000 < $end
           ORDER BY timestamp ASC LIMIT 1;" 2>/dev/null | sed 's/^/- /' || true
        sqlite3 "$tmp/history.db" \
          "SELECT 'last: ' || time(timestamp/1000000000,'unixepoch','localtime')
           FROM history WHERE timestamp/1000000000 >= $start AND timestamp/1000000000 < $end
           ORDER BY timestamp DESC LIMIT 1;" 2>/dev/null | sed 's/^/- /' || true
        # lag() over the day's rows: any neighbour pair more than 90min apart
        echo "- quiet gaps (>90min):"
        sqlite3 "$tmp/history.db" \
          "WITH t AS (SELECT timestamp/1000000000 s FROM history
                      WHERE timestamp/1000000000 >= $start AND timestamp/1000000000 < $end
                      ORDER BY s)
           SELECT '    ' || time(prev,'unixepoch','localtime') || ' -> '
                  || time(s,'unixepoch','localtime')
                  || ' (' || ((s-prev)/3600) || 'h' || (((s-prev)%3600)/60) || 'm)'
           FROM (SELECT s, lag(s) OVER (ORDER BY s) prev FROM t)
           WHERE prev IS NOT NULL AND s-prev > 5400;" 2>/dev/null || true
        # sleep = last command yesterday -> first command today
        sqlite3 "$tmp/history.db" \
          "SELECT '- sleep-ish gap: ' || time(a,'unixepoch','localtime') || ' -> '
                  || time(b,'unixepoch','localtime') || ' (' || ((b-a)/3600) || 'h'
                  || (((b-a)%3600)/60) || 'm)'
           FROM (SELECT (SELECT max(timestamp)/1000000000 FROM history
                         WHERE timestamp/1000000000 < $start) a,
                        (SELECT min(timestamp)/1000000000 FROM history
                         WHERE timestamp/1000000000 >= $start
                           AND timestamp/1000000000 < $end) b)
           WHERE a IS NOT NULL AND b IS NOT NULL AND b-a > 10800;" 2>/dev/null || true
      fi
      # away-from-mains spans from the sampler (10min granularity)
      pf="''${XDG_DATA_HOME:-$HOME/.local/share}/soft/power-$day"
      if [ -e "$pf" ]; then
        awk -F'\t' '
          $2==0 && !on { on=1; from=$1 }
          $2==1 && on  { on=0; print "- on battery: " from " -> " $1 }
          END { if (on) print "- on battery: " from " -> still" }
        ' "$pf" || true
      fi

      echo
      echo "## reading (koreader)"
      kdb=""
      for c in "$HOME/.config/koreader/settings/statistics.sqlite3" \
               "$HOME/.config/koreader/statistics.sqlite3" \
               "$HOME/koreader/settings/statistics.sqlite3"; do
        [ -e "$c" ] && { kdb="$c"; break; }
      done
      if [ -n "$kdb" ]; then
        cp -f "$kdb" "$tmp/koreader.db" 2>/dev/null || true
        sqlite3 -separator ' | ' "$tmp/koreader.db" \
          "SELECT b.title, count(*) || ' pages',
                  (sum(s.duration)/60) || ' min'
           FROM page_stat_data s JOIN book b ON b.id = s.id_book
           WHERE s.start_time >= $start AND s.start_time < $end
           GROUP BY b.id ORDER BY sum(s.duration) DESC;" 2>/dev/null \
          | sed 's/^/- /' || true
      else
        echo "(no koreader stats db)"
      fi

      # networks joined today: the travel day's shape (airport -> hotel -> con).
      # nmcli prints its own local timestamp string, so filter on the date text.
      echo
      echo "## networks"
      if command -v nmcli >/dev/null 2>&1; then
        # wifi only: the tun/bridge/docker connections say nothing about place.
        nmcli -t -f NAME,TYPE,TIMESTAMP-REAL connection show 2>/dev/null \
          | grep 'wireless' | grep -F "$(date -d "$day" '+%d %b %Y')" \
          | sed 's/\\:/:/g; s/:802-11-wireless:/ @ /; s/^/- /' | head -12 || true
      fi

      echo
      echo "## system generations switched today"
      find /nix/var/nix/profiles -maxdepth 1 -name 'system-*-link' \
        -newermt "$day 00:00" ! -newermt "$next 00:00" \
        -printf '- %f (%TH:%TM)\n' 2>/dev/null | sort || true

      echo
      echo "## watched (mpv)"
      mh="''${XDG_STATE_HOME:-$HOME/.local/state}/mpv/history.log"
      if [ -e "$mh" ]; then
        grep -F "$day " "$mh" 2>/dev/null | cut -f2 | sort -u | sed 's/^/- /' | head -20 || true
      else
        echo "(no mpv history yet)"
      fi

      # RE/CTF work leaves case dirs and notes, which git alone misses (a case
      # dir is deliberately NOT a repo). flags are MASKED: the fact of a solve
      # belongs in a diary, the flag string does not.
      echo
      echo "## re / ctf"
      for root in "$HOME/pentest" "$HOME/workspace"; do
        [ -d "$root" ] || continue
        find "$root" -maxdepth 3 -type d -name case \
          -newermt "$day 00:00" ! -newermt "$next 00:00" \
          -printf '- case touched: %p\n' 2>/dev/null || true
      done | head -12
      # only notes edited TODAY, so an old solve does not re-log every night.
      find "$HOME/workspace" "$HOME/pentest" -type f \
        \( -name '*.md' -o -name '*.txt' \) \
        -newermt "$day 00:00" ! -newermt "$next 00:00" 2>/dev/null \
        | while IFS= read -r ff; do
            n=$(grep -cE 'flag\{|CTF\{|dc34\{' "$ff" 2>/dev/null || true)
            [ -n "$n" ] && [ "$n" -gt 0 ] 2>/dev/null || continue
            echo "- $n flag(s) recorded in ''${ff#"$HOME"/} (values withheld)"
          done | head -8 || true

      # the boxes she reached from here today, from atuin. remote work is work.
      echo
      echo "## remote sessions"
      if [ -e "$tmp/history.db" ]; then
        sqlite3 "$tmp/history.db" \
          "SELECT DISTINCT substr(command,1,60) FROM history
           WHERE timestamp/1000000000 >= $start AND timestamp/1000000000 < $end
             AND command LIKE 'ssh %' LIMIT 10;" 2>/dev/null | sed 's/^/- /' || true
      fi

      # what pinged her, counts by app only. mako keeps no history file, so this
      # reads the journal's notification traffic; absent journal = silent leg.
      echo
      echo "## notifications"
      journalctl --user --since "$day 00:00" --until "$next 00:00" \
        -t care -t mako --no-pager -o cat 2>/dev/null | wc -l \
        | sed 's/^/- care\/mako journal lines: /' || true

      # screenshots are evidence of what was on screen. OCR them for wording
      # hints only; the SKILL never quotes them and they never get embedded.
      echo
      echo "## screenshots (ocr hints)"
      find "$HOME/Pictures" -maxdepth 1 -name 'screenshot-*.png' \
        -newermt "$day 00:00" ! -newermt "$next 00:00" 2>/dev/null | head -8 \
        | while IFS= read -r shot; do
            txt=$(tesseract "$shot" - --psm 6 2>/dev/null \
              | tr '\n' ' ' | tr -s ' ' | cut -c1-200 || true)
            [ -z "$txt" ] || echo "- $(basename "$shot"): $txt"
          done || true

      # clipboard: KINDS and counts only, never contents. clipse stores plain
      # text verbatim (passwords, tokens, private messages all pass through it),
      # so nothing from here may ever reach the note beyond a shape.
      echo
      echo "## clipboard (shape only)"
      ch="$HOME/.config/clipse/clipboard_history.json"
      if [ -e "$ch" ]; then
        jq -r --arg d "$day" '
          [.clipboardHistory[]? | select((.recorded? // "") | startswith($d))]
          | "- \(length) clips today"' "$ch" 2>/dev/null || true
      fi

      # the wearable's own account of the day. PRIVACY, and this is the whole
      # design of this leg: bee records ambient audio, so its conversations
      # contain OTHER PEOPLE who never agreed to be in a synced (and partly
      # published) vault. so only the daily SUMMARY and a bare conversation
      # COUNT come out here; transcripts and titles stay on disk under the
      # state dir, readable by hand when she wants them, never auto-harvested.
      # fail-soft: no cli, no login, or no network = a silent skip.
      echo
      echo "## bee (wearable)"
      if command -v bee >/dev/null 2>&1 && bee status >/dev/null 2>&1; then
        bstate="''${XDG_STATE_HOME:-$HOME/.local/state}/bee-sync"
        mkdir -p "$bstate"
        timeout 90 bee sync --recent-days 2 --output "$bstate" >/dev/null 2>&1 || true

        # bee writes the day's summary only once the day is over, so ask the api
        # directly first, fall back to the synced copy, and if neither exists
        # (the usual case mid-day) fall back to the per-conversation SHORT
        # SUMMARY blocks. never the transcriptions: those are the raw audio of
        # other people and stay on disk only.
        sum="$bstate/daily/$day/summary.md"
        if timeout 30 bee daily find "$day" 2>/dev/null | grep -qv '^No daily summary'; then
          timeout 30 bee daily find "$day" 2>/dev/null | sed 's/^/  /' | head -40 || true
        elif [ -e "$sum" ]; then
          sed 's/^/  /' "$sum" | head -40 || true
        fi

        cdir="$bstate/conversations/$day"
        if [ -d "$cdir" ]; then
          echo "- $(find "$cdir" -type f | wc -l) conversation(s) captured (transcripts withheld, on disk at $cdir)"
          echo "- short summaries:"
          for cf in "$cdir"/*.md; do
            [ -e "$cf" ] || continue
            # the block between '## Short Summary' and the next heading, capped:
            # a condensation of her day, not a record of anyone's speech.
            sed -n '/^## Short Summary/,/^#/p' "$cf" 2>/dev/null \
              | sed '1d;/^#/d;/^$/d' | head -6 | sed 's/^/    /' || true
          done
        fi
      else
        echo "(bee cli absent or not logged in)"
      fi

      echo
      echo "## vault files touched"
      find "$HOME/vault" -name '*.md' \
        -newermt "$day 00:00" ! -newermt "$next 00:00" \
        -not -path '*/.obsidian/*' 2>/dev/null | sed "s|^$HOME/vault/|- |" | head -30 || true
    '';
  };

  # daylog-iphone: the interim photo path while nextcloud auto-upload is not set
  # up on the phone. the SKILL asks her to plug the iphone in, then runs this:
  # wait for the device, mount the media partition, copy the day's camera-roll
  # shots into ~/Pictures/iphone-import/<date>/ (heic converted to jpg so both
  # claude's eyes and obsidian embeds can read them), unmount, list what landed.
  # the import dir gets today's mtime, so daylog-harvest picks the files up as
  # candidates on its next run with no extra plumbing.
  # linux-only, and it NEEDS rice.iphone on the host (usbmuxd owns the socket;
  # fusermount comes from the system's setuid wrapper, deliberately NOT from
  # runtimeInputs where an unprivileged copy would shadow it).
  daylogIphone = pkgs.writeShellApplication {
    name = "daylog-iphone";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.libimobiledevice
      pkgs.ifuse
      pkgs.libheif.bin
    ];
    text = ''
      day="''${1:-$(date +%F)}"
      case "$day" in
        [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
        *) echo "usage: daylog-iphone [YYYY-MM-DD]" >&2; exit 1 ;;
      esac
      next=$(date -d "$day + 1 day" +%F)
      dest="$HOME/Pictures/iphone-import/$day"

      # wait for the phone: plugged, unlocked, and trusted. 90s is long enough
      # to fish it out of a bag, short enough that a forgotten run dies quietly.
      echo "waiting for the iphone (plug in + unlock, tap trust if asked)..."
      t=0
      until idevice_id -l 2>/dev/null | grep -q .; do
        t=$((t + 3))
        [ "$t" -lt 90 ] || { echo "daylog-iphone: no device after 90s" >&2; exit 1; }
        sleep 3
      done

      # pairing may need the trust tap; validate first so a known phone is silent.
      idevicepair validate >/dev/null 2>&1 || {
        echo "pairing (tap trust on the phone)..."
        ok=0
        for _ in 1 2 3 4 5 6; do
          if idevicepair pair >/dev/null 2>&1 && idevicepair validate >/dev/null 2>&1; then
            ok=1
            break
          fi
          sleep 5
        done
        [ "$ok" -eq 1 ] || { echo "daylog-iphone: pairing failed (locked? trust not tapped?)" >&2; exit 1; }
      }

      mnt=$(mktemp -d)
      cleanup() { fusermount -u "$mnt" 2>/dev/null || umount "$mnt" 2>/dev/null || true; rmdir "$mnt" 2>/dev/null || true; }
      trap cleanup EXIT
      ifuse "$mnt"

      mkdir -p "$dest"
      n=0
      while IFS= read -r f; do
        base=$(basename "$f")
        case "''${f,,}" in
          *.heic)
            # heif-dec, not imagemagick: tiny closure, and jpg is what obsidian
            # and the picker can actually display.
            heif-dec -q 92 "$f" "$dest/''${base%.*}.jpg" >/dev/null 2>&1 || continue
            ;;
          *) cp -n "$f" "$dest/$base" 2>/dev/null || continue ;;
        esac
        n=$((n + 1))
      done < <(find "$mnt/DCIM" -type f \
        \( -iname '*.heic' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) \
        -newermt "$day 00:00" ! -newermt "$next 00:00" 2>/dev/null)

      echo "imported $n photo(s) for $day into $dest:"
      find "$dest" -type f -printf '- %p\n' 2>/dev/null || true
    '';
  };

  # power sampler: one line every 10 minutes recording whether the laptop is on
  # mains. cheap proxy for "away from the desk" spans that upower/journald do
  # not keep historically (the journal only has the transition events, and they
  # vanish with the ring buffer's retention). linux-only, harmless on a desktop
  # (it just records a flat line of 1s).
  powerSample = pkgs.writeShellApplication {
    name = "daylog-power-sample";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      f="''${XDG_DATA_HOME:-$HOME/.local/share}/soft/power-$(date +%Y-%m-%d)"
      mkdir -p "$(dirname "$f")"
      on=0
      for s in /sys/class/power_supply/A*/online; do
        [ -e "$s" ] || continue
        [ "$(cat "$s" 2>/dev/null || echo 0)" = "1" ] && on=1
      done
      printf '%s\t%s\n' "$(date +%H:%M)" "$on" >> "$f"
    '';
  };

  daylog = pkgs.writeShellApplication {
    name = "daylog";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      vault=${lib.escapeShellArg cfg.vault}
      day=""
      projects=0
      wind=0

      usage() {
        printf 'daylog -- log today into the obsidian daily note, via claude\n'
        printf '  daylog                     log today\n'
        printf '  daylog -p, --projects      also sweep ~/vault/projects first\n'
        printf '  daylog -n, --night         wind-down: log, tidy the plan, hand to cozy\n'
        printf '  daylog -d, --date <date>   backfill a specific YYYY-MM-DD\n'
      }

      while [ $# -gt 0 ]; do
        case "$1" in
          -p | --projects) projects=1 ;;
          -n | --night) wind=1 ;;
          -d | --date)
            shift
            day="''${1:-}"
            [ -n "$day" ] || { echo "daylog: --date needs a YYYY-MM-DD" >&2; exit 1; }
            ;;
          -h | --help) usage; exit 0 ;;
          *) echo "daylog: unknown argument '$1'" >&2; usage >&2; exit 1 ;;
        esac
        shift
      done

      # a bad date silently writes daily/garbage.md, which then syncs everywhere,
      # so validate the shape before it can reach the vault.
      if [ -n "$day" ]; then
        case "$day" in
          [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
          *) echo "daylog: --date must be YYYY-MM-DD, got '$day'" >&2; exit 1 ;;
        esac
      else
        day="$(date +%F)"
      fi

      [ -d "$vault" ] || { echo "daylog: no vault at $vault" >&2; exit 1; }
      command -v claude >/dev/null 2>&1 || {
        echo "daylog: claude code not on PATH" >&2
        exit 1
      }

      # coarse, ip-based "where am i today". this is the interim source: the real
      # one is phone-side (ios shortcut -> vault file, see the daily-log-harvest
      # project). fail SOFT and SILENT: a vpn, a captive portal, or being offline
      # must never write a wrong place into a synced diary. only pass a location
      # when the lookup actually succeeds; the skill omits the line otherwise.
      # ip-api.com over http (no key, no tls handshake to stall on); 6s ceiling.
      loc=""
      if geo="$(curl -fsS --max-time 6 \
          'http://ip-api.com/json/?fields=status,city,regionName,country' 2>/dev/null)" \
        && [ "$(printf '%s' "$geo" | jq -r '.status // empty')" = "success" ]; then
        city="$(printf '%s' "$geo" | jq -r '.city // empty')"
        region="$(printf '%s' "$geo" | jq -r '.regionName // empty')"
        [ -n "$city" ] && loc="$city''${region:+, $region} (ip)"
      fi

      prompt="run /daily-log for $day."
      [ "$projects" -eq 1 ] && prompt="run /project-sync first, then /daily-log for $day."
      [ "$wind" -eq 1 ] && prompt="run /wind-down for $day."
      [ -n "$loc" ] && prompt="$prompt current location: $loc."

      # cwd is the vault so the session's file tools land in the right tree and
      # any vault-local CLAUDE.md applies; the skill still reaches ~/.claude and
      # the code repos by absolute path for harvesting.
      cd "$vault" || exit 1
      exec claude "$prompt"
    '';
  };
in
{
  options.rice.daylog = {
    enable = lib.mkEnableOption "the `daylog` command (daily note, filled by claude)";
    vault = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/vault";
      description = "obsidian vault holding daily/<date>.md";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      daylog
      daylogHarvest
      # the Bee wearable's cli. inert until `bee login` writes credentials, so
      # shipping it costs nothing on a host that has no wearable.
      # TODO(deploy): run `bee login` once per box to enable the wearable leg.
      (pkgs.callPackage ../../../pkgs/bee-cli/package.nix { })
    ]
    # usb photo import + the power sampler are linux-only (usbmuxd/ifuse,
    # power_supply sysfs); the macs sync via icloud + nextcloud and never need
    # the cable path.
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      daylogIphone
      powerSample
    ];

    # the sampler only makes sense where it can run on a timer, hence the same
    # linux gate. 10min granularity: fine for "at the desk or not", cheap enough
    # to be invisible.
    systemd.user = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      services.daylog-power-sample = {
        Unit.Description = "sample AC state for the daylog day-shape";
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe powerSample;
        };
      };
      timers.daylog-power-sample = {
        Unit.Description = "sample AC state every 10 minutes";
        Timer = {
          OnBootSec = "2m";
          OnUnitActiveSec = "10m";
          Persistent = false;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
