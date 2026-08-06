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
  # repo roots, zen browser history, plan, vault files touched) and prints one
  # markdown report the skill edits down. exists because the skill used to
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
    ];
    text = ''
      day="''${1:-$(date +%F)}"
      case "$day" in
        [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
        *) echo "usage: daylog-harvest [YYYY-MM-DD]" >&2; exit 1 ;;
      esac
      start=$(date -d "$day 00:00" +%s)
      end=$((start + 86400))

      echo "# daylog harvest for $day on $(uname -n)"

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

      echo
      echo "## vault files touched"
      find "$HOME/vault" -name '*.md' \
        -newermt "$day 00:00" ! -newermt "$day 23:59:59" \
        -not -path '*/.obsidian/*' 2>/dev/null | sed "s|^$HOME/vault/|- |" | head -30 || true
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
    ];
  };
}
