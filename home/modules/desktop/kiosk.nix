# shared machinery for the two AFK Chromium kiosks (dashboard.nix, datamosh.nix): the
# idle watcher and the data.json updater skeleton were verbatim copies, so they live here
# once and a fix (e.g. the darwin procps pgrep/pkill gap) lands in both instead of
# drifting apart. a plain function file, NOT a home-manager module: it must never appear
# in an imports list (home/coral.nix imports modules by explicit path, so it stays inert).
{ pkgs }:
let
  # min HIDIdleTime across all HID nodes, ns -> s. the watcher and the updater sample the
  # SAME source so the page's idle tiers agree with the launch/teardown decisions.
  idleSecondsFn = ''
    idle_seconds() {
      /usr/sbin/ioreg -c IOHIDSystem 2>/dev/null | ${pkgs.gnugrep}/bin/grep '"HIDIdleTime"' \
        | ${pkgs.gawk}/bin/awk '{ for (i=1;i<=NF;i++) if ($i+0==$i){v=$i;break} if(min==""||v<min)min=v }
                  END { if(min=="")print 0; else printf "%d\n", min/1000000000 }'
    }
  '';
in
{
  # the idle watcher: launches the kiosk past idleSeconds of no HID input, tears it down
  # the instant input returns. single-instance (pkill the unique tag) + cooldown, so it
  # can never flood the box. `name` must NOT contain `tag`: the watcher's own cmdline
  # carries its store path, so a tag-bearing script name would make the `pkill -f $TAG`
  # in start/stop kill the watcher itself.
  mkWatcher =
    {
      name,
      tag,
      outDir,
      profileDir,
      htmlFile,
      updater,
      updaterName,
      idleSeconds,
      pollSeconds,
    }:
    pkgs.writeShellScript "${name}-watcher" ''
      set -u
      # nixpkgs procps on darwin is the POSIX shim (ps/sysctl/top/watch only), no
      # pgrep/pkill; the OS-fixed BSD ones live in /usr/bin, same pattern as ioreg/open.
      PGREP="/usr/bin/pgrep"
      PKILL="/usr/bin/pkill"
      SLEEP="${pkgs.coreutils}/bin/sleep"
      DATE="${pkgs.coreutils}/bin/date"
      CP="${pkgs.coreutils}/bin/cp"
      MKDIR="${pkgs.coreutils}/bin/mkdir"

      THRESHOLD=${toString idleSeconds}
      POLL=${toString pollSeconds}
      COOLDOWN=90
      last_launch=0
      out="${outDir}"
      profile="${profileDir}"
      TAG="${tag}"   # unique --user-data-dir suffix used as the process tag

      ${idleSecondsFn}
      kiosk_running() { "$PGREP" -f "$TAG" >/dev/null 2>&1; }

      start_kiosk() {
        # single-instance: kill any stray kiosk + its updater first.
        "$PKILL" -f "$TAG" >/dev/null 2>&1 || true
        "$PKILL" -f "${updaterName}" >/dev/null 2>&1 || true
        "$MKDIR" -p "$out"
        "$CP" -f "${htmlFile}" "$out/index.html"
        # updater feeds data.json; backgrounded, the watcher persists so it is not HUP'd.
        "${updater}" >/dev/null 2>&1 &
        # `open` foregrounds + Chromium --start-fullscreen fullscreens. the --user-data-dir
        # is $TAG so pgrep/pkill match exactly this kiosk, never a real browser window nor
        # the other kiosk. --start-fullscreen (NOT --kiosk): Cmd+Q/Cmd+W stay a guaranteed
        # manual exit so it can never trap the screen; the watcher also auto-dismisses on
        # input below.
        /usr/bin/open -na Chromium --args \
          --app="file://$out/index.html" --start-fullscreen \
          --user-data-dir="$profile-$TAG" \
          --allow-file-access-from-files --no-first-run --no-default-browser-check \
          --disable-infobars --disable-translate --noerrdialogs --disable-session-crashed-bubble \
          >/dev/null 2>&1 &
      }
      stop_kiosk() {
        "$PKILL" -f "$TAG" >/dev/null 2>&1 || true
        "$PKILL" -f "${baseNameOf outDir}/index.html" >/dev/null 2>&1 || true
        "$PKILL" -f "${updaterName}" >/dev/null 2>&1 || true
      }

      while :; do
        idle="$(idle_seconds)"
        if [ -z "$idle" ] || ! [ "$idle" -eq "$idle" ] 2>/dev/null; then idle=0; fi
        if [ "$idle" -ge "$THRESHOLD" ]; then
          if ! kiosk_running; then
            now="$("$DATE" +%s)"
            if [ "$((now - last_launch))" -ge "$COOLDOWN" ]; then start_kiosk; last_launch="$now"; fi
          fi
        else
          kiosk_running && stop_kiosk
        fi
        "$SLEEP" "$POLL"
      done
    '';

  # the data.json updater skeleton: samples idle, sanitizes it, then runs writePayload,
  # a per-iteration shell snippet that reads $idle and $out and must end in the atomic
  # .data.json.tmp + mv write. the two kiosks' payloads share nothing (rich telemetry
  # object vs idle-only), so this is a skeleton with a hole, not a base plus extension.
  mkUpdater =
    {
      name,
      outDir,
      writePayload,
    }:
    pkgs.writeShellScript name ''
      set -u
      out="${outDir}"
      ${pkgs.coreutils}/bin/mkdir -p "$out"
      ${idleSecondsFn}
      while :; do
        idle=$(idle_seconds)
        if [ -z "$idle" ] || ! [ "$idle" -eq "$idle" ] 2>/dev/null; then idle=0; fi
        ${writePayload}
        ${pkgs.coreutils}/bin/sleep 3
      done
    '';
}
