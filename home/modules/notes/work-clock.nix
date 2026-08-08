# work-clock: the office clock, three verbs.
#
#   work-in           stamps arrival into <vault>/work/work-YYYY-MM-DD.md
#   work-out          stamps leaving
#   work-log "line"   the one sentence per day the monthly timesheet keeps
#
# the ledger is plain frontmatter (clock-in / clock-out / break / log) on one
# tiny note per worked day; moc-work + work/work-clock.base in the vault do the
# live rollup, and the monthly freeze (work/timesheet-YYYY-MM.md) is what the
# boss receives. hours are never stored, always computed from the two stamps,
# so a corrected stamp cannot leave a stale total behind.
#
# write semantics, deliberately asymmetric:
#   - work-in CREATES the note directly on disk (offline-safe; a create cannot
#     clobber an open editor): first arrival wins, a re-run just shows the
#     existing stamp.
#   - work-out / work-log write through the obsidian-advanced-uri plugin
#     (pinned in obsidian-publish.nix) so the edit goes through obsidian's own
#     frontmatter processor and never fights an open tab or Sync. frontmatter
#     writes overwrite, so last leave wins. obsidian must be running for these
#     two; work-in never needs it.
#
# the iphone shortcuts fire the exact same uris, one funnel on every device
# (recipe: vault note work-clock-capture). uri routing is by vault NAME as the
# vault switcher shows it, not by path; see rice.workClock.obsidianVault.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.workClock;

  # shared bash prelude: today's paths + the note skeleton. the uri plumbing is
  # separate so work-in (pure filesystem) doesn't carry functions it never
  # calls (shellcheck SC2329 fails the build on those).
  # skeleton keys match templates/work-day.md in the vault; change together.
  prelude = ''
    day="$(date +%F)"
    note="${cfg.vault}/work/work-$day.md"

    skeleton() { # $1 = clock-in value, may be empty
      printf -- '---\ntags: work\nclock-in: %s\nclock-out: \nbreak: \nlog: \n---\n\n# work · %s\n\nday: [[%s]]\n' "$1" "$day" "$day"
    }
  '';

  # the arrival/leave stamp, split from the prelude for the same reason the
  # uri plumbing is: work-log never reads it, and SC2034 fails the build on an
  # unused assignment.
  nowStamp = ''
    now="$(date +%FT%H:%M)"
  '';

  uriPlumbing = ''
    enc() { jq -rn --arg v "$1" '$v|@uri'; }

    adv_uri() { # $1 = frontmatter key, $2 = value
      printf 'obsidian://adv-uri?vault=%s&filepath=%s&frontmatterkey=%s&data=%s' \
        "$(enc ${lib.escapeShellArg cfg.obsidianVault})" \
        "$(enc "work/work-$day.md")" \
        "$1" \
        "$(enc "$2")"
    }

    open_uri() {
      if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$1" >/dev/null 2>&1
      else
        open "$1"
      fi
    }

    # for the uri verbs: make sure today's note exists (clock-in left empty,
    # never faked), and give obsidian's watcher a beat to index a fresh file
    # before the uri writes into it.
    ensure_note() {
      if [ ! -e "$note" ]; then
        mkdir -p "$(dirname "$note")"
        skeleton "" > "$note"
        sleep 1
      fi
    }
  '';

  work-in = pkgs.writeShellApplication {
    name = "work-in";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
    ];
    text = ''
      ${prelude}
      ${nowStamp}
      mkdir -p "$(dirname "$note")"
      if [ -e "$note" ]; then
        existing="$(grep -m1 '^clock-in:' "$note" | sed 's/^clock-in:[[:space:]]*//' || true)"
        echo "already on the clock ($day): $existing"
        exit 0
      fi
      skeleton "$now" > "$note"
      echo "on the clock: $now .. work/work-$day.md"
    '';
  };

  work-out = pkgs.writeShellApplication {
    name = "work-out";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.xdg-utils ];
    text = ''
      ${prelude}
      ${nowStamp}
      ${uriPlumbing}
      ensure_note
      open_uri "$(adv_uri clock-out "$now")"
      echo "off the clock: $now"
    '';
  };

  work-log = pkgs.writeShellApplication {
    name = "work-log";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.xdg-utils ];
    text = ''
      ${prelude}
      ${uriPlumbing}
      if [ $# -lt 1 ]; then
        echo 'usage: work-log "what the day was"' >&2
        exit 2
      fi
      ensure_note
      open_uri "$(adv_uri log "$*")"
      echo "logged: $*"
    '';
  };
in
{
  options.rice.workClock = {
    enable = lib.mkEnableOption "the office clock (work-in / work-out / work-log)";

    vault = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/vault";
      description = "obsidian vault holding work/work-<date>.md";
    };

    obsidianVault = lib.mkOption {
      type = lib.types.str;
      default = "vault";
      description = ''
        the vault's NAME exactly as obsidian's vault switcher shows it (adv-uri
        routes by name and silently no-ops on a mismatch).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      work-in
      work-out
      work-log
    ];
  };
}
