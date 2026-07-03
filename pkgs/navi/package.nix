# navi: a full-screen Copland-OS cockpit you leave up on a monitor (Serial Experiments
# Lain, blood variant). it is the persistent kiosk sibling of the one-shot `wired` nushell
# command (home/modules/shell/nushell.nix): same masthead, same NAVI/CYBERIA/PROTOCOL7 node
# map, but it owns the whole screen and redraws on a loop until you Ctrl-C out.
#
# what it draws, top to bottom:
#   masthead   ||  COPLAND OS ENTERPRISE  //  EXTERNAL WIRED INTERFACE  ||
#   telemetry  ALL-CAPS field:value (CPU / MEM / LOAD / UPTIME / DISK) from macOS tools
#              (top -l1, vm_stat, sysctl, df, uptime). flat, one accent + dim, no chrome.
#   node map   parse `tailscale status`: each peer drawn as its Navi name with an online dot.
#   log tail   the last N lines of a chosen logfile, dimmed, the scrolling substrate.
#
# theme: a script cannot read nix at runtime, so the palette is BAKED IN at build time as
# 24-bit ANSI escapes (38;2;r;g;b) derived from theme.palette here. NEVER hardcode hex; every
# color reads `theme`. `theme` is a callPackage arg defaulting to the repo theme.nix, so the
# registration line in pkgs/default.nix stays `pkgs.callPackage ./navi/package.nix { }` (that
# file has no `theme` specialArg in scope) while still ACCEPTING an explicit theme if ever
# threaded. one accent + one dim, brightness carries hierarchy (the show's P1-phosphor logic):
# accent = palette.mauve, dim = palette.subtext0, text = palette.text, alarm = palette.red.
#
# wiring: this is just a package. the kiosk launchd/login plumbing (if any) lives in a home
# module; run it by hand in a terminal you leave open. tailscale is the nix-darwin system
# profile path (stable across rebuilds), matching wired-sound's tailwatch.
{
  lib,
  writeShellApplication,
  coreutils,
  gnugrep,
  gnused,
  gawk,
  theme ? import ../../theme.nix,
}:
let
  inherit (theme) palette;

  # "#rrggbb" -> "r;g;b" (decimal) for a 24-bit SGR escape. parse each hex pair by hand so the
  # derivation needs no extra tooling; mirrors wallpaper-gen.nix's hexPair.
  hexDigit =
    c:
    {
      "0" = 0;
      "1" = 1;
      "2" = 2;
      "3" = 3;
      "4" = 4;
      "5" = 5;
      "6" = 6;
      "7" = 7;
      "8" = 8;
      "9" = 9;
      a = 10;
      b = 11;
      c = 12;
      d = 13;
      e = 14;
      f = 15;
    }
    .${lib.toLower c};
  hexPair =
    s: o: (hexDigit (builtins.substring o 1 s)) * 16 + hexDigit (builtins.substring (o + 1) 1 s);
  # hex -> full SGR foreground escape string, baked into the script as a $'...' literal value.
  fg =
    hex:
    let
      h = builtins.substring 1 6 hex; # drop leading '#'
      r = toString (hexPair h 0);
      g = toString (hexPair h 2);
      b = toString (hexPair h 4);
    in
    "\\033[38;2;${r};${g};${b}m";

  accent = fg palette.mauve; # THE accent (muted plum-rose)
  dim = fg palette.subtext0; # the lone dim, labels + substrate
  text = fg palette.text; # soft purple-grey, the few "live" values
  alarm = fg palette.red; # reserved: offline / failure, never decoration

  # the system profile tailscale, not a /nix/store hash: stable across rebuilds so a long-lived
  # kiosk keeps working after a switch. matches wired-sound's baked @TAILSCALE@.
  tailscaleBin = "/run/current-system/sw/bin/tailscale";

  # macOS-fixed telemetry binaries: pinned absolute so the kiosk does not depend on PATH.
  topBin = "/usr/bin/top";
  vmStatBin = "/usr/bin/vm_stat";
  sysctlBin = "/usr/sbin/sysctl";
  dfBin = "/bin/df";
  uptimeBin = "/usr/bin/uptime";
in
writeShellApplication {
  name = "navi";

  # writeShellApplication injects `set -o errexit` by default and a body-level
  # `set -uo pipefail` cannot undo it. errexit breaks the fail-soft kiosk design:
  # with pipefail on, a failing `hostname` in draw()'s me=$(...) assignment kills
  # the redraw loop before the me:-unknown fallback runs. nounset + pipefail only.
  bashOptions = [
    "nounset"
    "pipefail"
  ];

  runtimeInputs = [
    coreutils
    gnugrep
    gnused
    gawk
  ];

  text = ''
    accent=$'${accent}'
    dim=$'${dim}'
    txt=$'${text}'
    alarm=$'${alarm}'
    reset=$'\033[0m'

    # ── tunables ──────────────────────────────────────────────────────────────
    # redraw cadence. 2s is slow enough that top -l1's 1s sample dominates, fast
    # enough to feel live. override for debugging with NAVI_INTERVAL.
    interval="''${NAVI_INTERVAL:-2}"
    # the scrolling substrate. system.log is the default but it is root:admin 0640,
    # so on a box where it is unreadable we degrade to "no log" rather than erroring.
    # point NAVI_LOGFILE at anything you'd rather watch (a build log, a tail target).
    logfile="''${NAVI_LOGFILE:-/var/log/system.log}"
    log_lines="''${NAVI_LOG_LINES:-12}"

    tailscale_bin='${tailscaleBin}'
    top_bin='${topBin}'
    vm_stat_bin='${vmStatBin}'
    sysctl_bin='${sysctlBin}'
    df_bin='${dfBin}'
    uptime_bin='${uptimeBin}'

    # the Navi: real nix hostname -> its wired name. mirrors nushell.nix's `wired`
    # map and the sketchybar dashboard. cosmetic only, NEVER renames the real host.
    navi_name() {
      case "$1" in
        otter)      printf 'NAVI' ;;
        coral)      printf 'CYBERIA' ;;
        *)          printf '%s' "$1" | tr '[:lower:]' '[:upper:]' ;;
      esac
    }

    # ── terminal state: own the alt-screen, hide the cursor, restore on the way out ──
    # cleanup runs on EXIT (covers Ctrl-C via SIGINT/SIGTERM too): show cursor, leave
    # the alt-screen, reset SGR. without this an interrupt strands a hidden cursor.
    cleanup() {
      printf '\033[?25h\033[?1049l%s' "$reset"
    }
    trap cleanup EXIT
    trap 'exit 0' INT TERM
    # enter alt-screen + hide cursor once, up front, so the redraw loop never flickers
    # the scrollback.
    printf '\033[?1049h\033[?25l'

    # ── field helpers ─────────────────────────────────────────────────────────
    # one ALL-CAPS field:value row. flat, label dim, value its own color. the label
    # is padded so the colon column lines up without a table.
    row() { # label value [valuecolor]
      local color="''${3:-$txt}"
      printf '  %s%-9s%s %s%s%s\n' "$dim" "$1" "$reset" "$color" "$2" "$reset"
    }

    # ── telemetry collectors. each fails soft to "?" so a kiosk never dies on a tool ──
    read_cpu() {
      # top -l1 prints "CPU usage: X% user, Y% sys, Z% idle". busy = 100 - idle.
      local idle
      idle=$("$top_bin" -l1 -n0 2>/dev/null \
        | grep -i 'CPU usage' \
        | sed -n 's/.*[, ]\([0-9.]*\)% idle.*/\1/p' | head -n1)
      if [ -n "$idle" ]; then
        awk -v i="$idle" 'BEGIN { printf "%.1f%% BUSY", (100 - i) }'
      else
        printf '?'
      fi
    }

    read_mem() {
      # vm_stat reports pages; page size from sysctl. "used" = physmem minus genuinely
      # free pages (free + speculative, which the kernel will hand back on demand), so
      # active/inactive/wired/compressed all read as used. that is the honest pressure
      # number, not the misleading "free" macOS likes to show.
      local psize total_bytes
      psize=$("$vm_stat_bin" 2>/dev/null | sed -n 's/.*page size of \([0-9]*\) bytes.*/\1/p')
      psize="''${psize:-16384}"
      total_bytes=$("$sysctl_bin" -n hw.memsize 2>/dev/null || echo 0)
      if [ "$total_bytes" -le 0 ]; then printf '?'; return; fi
      "$vm_stat_bin" 2>/dev/null | awk -v ps="$psize" -v tot="$total_bytes" '
        /Pages free/                 { gsub(/\./,""); free=$3 }
        /Pages speculative/          { gsub(/\./,""); free+=$3 }
        END {
          used = tot - (free * ps)
          if (used < 0) used = 0
          printf "%.1f / %.1f GB", used/1073741824, tot/1073741824
        }'
    }

    read_load() {
      # vm.loadavg is "{ 1.23 4.56 7.89 }"; pull the three numbers.
      "$sysctl_bin" -n vm.loadavg 2>/dev/null \
        | sed 's/[{}]//g' | awk '{ printf "%s  %s  %s", $1, $2, $3 }' || printf '?'
    }

    read_uptime() {
      # uptime's "up ..., N users, load..." -> just the "up ..." span.
      "$uptime_bin" 2>/dev/null \
        | sed -n 's/.*up *\(.*\), *[0-9]* user.*/\1/p' | sed 's/^ *//;s/ *$//' || printf '?'
    }

    read_disk() {
      # df -k on the data volume, root mount. POSIX -k so the columns are stable.
      "$df_bin" -k / 2>/dev/null | awk 'NR==2 {
        printf "%.0f / %.0f GB  (%s)", ($3)/1048576, ($2)/1048576, $5
      }' || printf '?'
    }

    # ── tailnet node map. parse `tailscale status` lines: col2 is the host, an
    # "offline" token anywhere marks it down. degrade silently if tailscale is absent. ──
    draw_nodes() {
      printf '%s  THE WIRED%s\n' "$dim" "$reset"
      if [ ! -x "$tailscale_bin" ]; then
        printf '    %s(no wired interface)%s\n' "$dim" "$reset"
        return
      fi
      local status
      status=$("$tailscale_bin" status 2>/dev/null) || {
        printf '    %s(wired down)%s\n' "$dim" "$reset"
        return
      }
      printf '%s\n' "$status" | while IFS= read -r line; do
        [ -n "$line" ] || continue
        local host nm
        host=$(printf '%s' "$line" | awk '{ print $2 }' | cut -d. -f1)
        [ -n "$host" ] || continue
        nm=$(navi_name "$(printf '%s' "$host" | tr '[:upper:]' '[:lower:]')")
        # online unless the line carries an "offline" token (case-insensitive).
        if printf '%s' "$line" | grep -qi 'offline'; then
          printf '    %s●%s %s%-12s%s %soffline%s\n' \
            "$alarm" "$reset" "$dim" "$nm" "$reset" "$dim" "$reset"
        else
          printf '    %s●%s %s%-12s%s %sonline%s\n' \
            "$accent" "$reset" "$txt" "$nm" "$reset" "$dim" "$reset"
        fi
      done
    }

    # ── log tail. the scrolling substrate. dimmed, truncated to terminal width so a
    # long line never wraps and shoves the layout. unreadable/absent -> a quiet note. ──
    draw_log() {
      local cols width
      cols="''${COLUMNS:-100}"
      # keep the truncation width sane on a narrow terminal so `cut` never sees <= 0.
      width=$(( cols - 6 ))
      [ "$width" -lt 20 ] && width=20
      printf '%s  LOG  %s%s%s\n' "$dim" "$reset" "$dim" "$logfile"
      printf '%s' "$reset"
      if [ -r "$logfile" ]; then
        tail -n "$log_lines" "$logfile" 2>/dev/null | while IFS= read -r l; do
          printf '    %s%s%s\n' "$dim" "$(printf '%s' "$l" | cut -c1-"$width")" "$reset"
        done
      else
        printf '    %s(no readable log at %s)%s\n' "$dim" "$logfile" "$reset"
      fi
    }

    # ── one frame ─────────────────────────────────────────────────────────────
    draw() {
      local me name
      me=$(hostname -s 2>/dev/null | tr '[:upper:]' '[:lower:]' | cut -d. -f1)
      me="''${me:-unknown}"
      name=$(navi_name "$me")

      # home the cursor + clear-to-end each frame instead of a full clear: less flicker
      # on the redraw loop, the alt-screen already isolated us from scrollback.
      printf '\033[H\033[J'

      printf '%s||  COPLAND OS ENTERPRISE  //  EXTERNAL WIRED INTERFACE  ||%s\n' "$accent" "$reset"
      printf '\n'

      row "NODE"   "$name  ($me)" "$accent"
      row "CPU"    "$(read_cpu)"
      row "MEM"    "$(read_mem)"
      row "LOAD"   "$(read_load)"
      row "UPTIME" "$(read_uptime)"
      row "DISK"   "$(read_disk)"
      printf '\n'

      draw_nodes
      printf '\n'

      draw_log
    }

    # redraw forever until interrupted. background the sleep + `wait` on it so a SIGINT
    # lands on the shell (firing the INT trap -> clean exit) instead of being swallowed
    # by sleep itself; a foreground `sleep` would eat the first Ctrl-C.
    while true; do
      draw
      sleep "$interval" &
      wait "$!"
    done
  '';

  meta = {
    description = "full-screen copland-os cockpit: telemetry + tailnet node map + log tail (serial experiments lain)";
    mainProgram = "navi";
    platforms = lib.platforms.darwin;
  };
}
