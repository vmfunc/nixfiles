# rice.daylog: the `daylog` command. opens claude code on today's daily note
# with the /daily-log skill already pointed at it, so "what did i actually do
# today" is one word instead of a prompt she has to retype every evening.
# `-n/--night` runs /wind-down instead (log + tidy plan + hand to cozy).
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

  config = lib.mkIf cfg.enable { home.packages = [ daylog ]; };
}
