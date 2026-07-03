# auth-flinch: the machine FLINCHES when an auth attempt is rejected. a mistyped sudo
# or login password plays the low detuned fail buzz (pkgs/wired-sound share/fail.wav),
# once, quiet. the security stack noticing you got it wrong, not an alarm. this is the
# auth-fail half that wired-sound.nix deliberately left out: that module skipped it for
# lack of a CLEAN per-failure hook, this one accepts a slightly-fragile log predicate as
# the cost of the flinch, and keeps it conservative + debounced so a burst is one buzz.
#
# how: a long-lived `log stream` follows the unified log filtered to authentication
# failures, and afplays the buzz on each match. no polling, no fake-hacker chrome, just
# the OS's own auth-reject events answered with one low note.
#
# the predicate (the FRAGILE part, documented in the script): we match sudo's own
# "incorrect password" / "N incorrect password attempts" lines and opendirectoryd's
# password-verification failures. these are the two stable surfaces for a mistyped sudo
# and a mistyped login/unlock respectively. it is intentionally NARROW: a missed failure
# is silent (acceptable), a false buzz on a SUCCESS would be off-thesis (avoided).
#
# imported only from home/profiles/desktop-darwin.nix (darwin desktops), so the launchd
# agent needs no platform guard, same as wired-sound.nix / autoraise.nix. afplay and log
# are OS-fixed (/usr/bin), pinned absolute so the agent does not depend on launchd's PATH.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  wired = pkgs.wired-sound;
  failBuzz = "${wired}/share/wired-sound/fail.wav";
  # LOW on purpose: the flinch is presence, not a notification. per the task, -v 0.3.
  buzzVolume = "0.3";
  logDir = "${config.home.homeDirectory}/Library/Logs";

  # the unified-log predicate for auth REJECTIONS. kept conservative:
  #   sudo                 -> "incorrect password attempts" is sudo's own pam_unix reject
  #                           line; "X incorrect password attempt(s)" is the same family.
  #   opendirectoryd       -> ODRecordVerifyPassword failed: the kernel of a mistyped
  #                           login / screen-unlock / Touch-ID fallback to password.
  # we match eventMessage substrings rather than message-format keys because the format
  # ids drift across macOS releases while the human text has stayed stable; this is the
  # FRAGILE seam, if Apple rewords these the buzz just goes quiet (fail-silent, fine).
  authFailPredicate =
    "(process == \"sudo\" AND eventMessage CONTAINS \"incorrect password\") "
    + "OR (process == \"opendirectoryd\" AND eventMessage CONTAINS \"ODRecordVerifyPassword\" "
    + "AND eventMessage CONTAINS \"failed\")";

  # debounce window: a single mistype emits several log lines (pam + opendirectoryd), and a
  # password retry burst should still be ONE flinch, not a machine-gun. 3s swallows the
  # cluster without missing a genuinely separate, later attempt.
  debounceSeconds = "3";

  flinch = pkgs.writeShellScript "auth-flinch" ''
    set -euo pipefail

    afplay="/usr/bin/afplay"
    log="/usr/bin/log"
    buzz="${failBuzz}"
    vol="${buzzVolume}"
    window="${debounceSeconds}"

    state="''${XDG_STATE_HOME:-$HOME/.local/state}/auth-flinch"
    laststamp="$state/last"
    mkdir -p "$state"

    # follow the unified log; each matching line is one candidate flinch. --style ndjson so a
    # line is one json object (we don't parse it, the predicate already did the filtering, we
    # only need "a line arrived"). a blank/dropped line is ignored by the guard below.
    "$log" stream --style ndjson --predicate ${lib.escapeShellArg authFailPredicate} \
    | while IFS= read -r line; do
        [ -z "$line" ] && continue

        # debounce: collapse a burst (pam + opendirectoryd for one mistype, or rapid retries)
        # into a single buzz. epoch seconds is enough granularity for a 3s window.
        now="$(date +%s)"
        if [ -f "$laststamp" ]; then
          prev="$(cat "$laststamp" 2>/dev/null || echo 0)"
          [ -z "$prev" ] && prev=0
          if [ "$((now - prev))" -lt "$window" ]; then
            continue
          fi
        fi
        printf '%s\n' "$now" >"$laststamp"

        # the flinch itself: one low buzz, detached so a slow afplay can't stall the stream.
        "$afplay" -v "$vol" "$buzz" >/dev/null 2>&1 &
      done
  '';
in
{
  # the watcher must live the whole session: KeepAlive=true is correct here. it does NOT
  # fork-and-exit (the `log stream` pipe blocks in the foreground, the afplay child is the
  # only fork and it's backgrounded), so there is no relaunch-loop risk. if `log stream`
  # ever dies, launchd brings the watcher back and the flinch keeps working.
  launchd.agents.auth-flinch = {
    enable = true;
    config = {
      ProgramArguments = [ "${flinch}" ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${logDir}/auth-flinch.log";
      StandardErrorPath = "${logDir}/auth-flinch.log";
    };
  };
}
