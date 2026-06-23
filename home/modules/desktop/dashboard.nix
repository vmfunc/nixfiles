# AFK-only external-display dashboard.
#
# coral is a clamshell desk machine (external display) as well as the always-on box, so the
# dashboard only shows when idle (no HID input for rice.dashboard.idleSeconds) and is torn
# down the instant input returns.
#
# RENDERER: Chromium in --start-fullscreen, launched via `open` (foregrounds + fullscreens). the old
# terminal-kiosk fought macOS at every layer (a daemon/asuser context cannot foreground a
# new GUI window, wezterm mux-attach, zellij session resurrection). a browser kiosk launched
# by `open` from the in-session launchd agent sidesteps all of that, and the content is plain
# HTML/CSS so it is easy to make nice and impossible to "not render".
#
# OPSEC, SHARED OFFICE: non-sensitive content only -- clock, system stats, and the PUBLIC
# .plan (plan.txt, %hidden filtered). nothing that exposes work.
#
# flood-proof: single-instance (pkill the unique --user-data-dir before launch) + a cooldown.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.dashboard;
  outDir = "${config.home.homeDirectory}/.cache/coral-dashboard";
  profileDir = "${outDir}/chrome-profile";

  # the page. catppuccin macchiato. clock is live JS; system + plan come from data.json
  # which the updater rewrites every few seconds (fetched same-dir via file://, allowed by
  # --allow-file-access-from-files). no JS template literals so nix does not eat the ${}.
  htmlFile = pkgs.writeText "coral-dashboard.html" ''
    <!doctype html><html><head><meta charset="utf-8"><title>coral</title><style>
      :root{--base:#24273a;--text:#cad3f5;--mauve:#c6a0f6;--green:#a6da95;--sub:#a5adcb;--surf:#363a4f;--peach:#f5a97f}
      *{margin:0;box-sizing:border-box}
      body{background:var(--base);color:var(--text);height:100vh;overflow:hidden;padding:5vh 5vw;
           font-family:'JetBrainsMono Nerd Font',ui-monospace,Menlo,monospace;
           display:grid;grid-template-columns:1fr 1fr;grid-template-rows:auto 1fr;gap:4vh 4vw}
      .clock{grid-column:1 / 3;text-align:center}
      .time{font-size:13vw;font-weight:800;color:var(--mauve);line-height:.95;letter-spacing:-.5vw}
      .date{font-size:2.6vw;color:var(--sub);margin-top:1vh}
      .card{background:var(--surf);border-radius:2vw;padding:3.5vh 3vw;overflow:hidden}
      .card h2{font-size:1.7vw;color:var(--green);margin-bottom:2.5vh;letter-spacing:.15vw}
      .stat{display:flex;justify-content:space-between;font-size:2vw;padding:.9vh 0;border-bottom:1px solid #494d64}
      .stat .v{color:var(--peach)}
      .plan{white-space:pre-wrap;font-size:1.6vw;line-height:1.6}
      .plan .doing{color:var(--mauve)}.plan .next{color:var(--green)}.plan .done{color:var(--sub)}
    </style></head><body>
      <div class="clock"><div class="time" id="time">--:--:--</div><div class="date" id="date"></div></div>
      <div class="card"><h2>system</h2><div id="stats"></div></div>
      <div class="card"><h2>.plan</h2><div class="plan" id="plan">loading...</div></div>
    <script>
      function tick(){var d=new Date();
        document.getElementById('time').textContent=d.toLocaleTimeString('en-GB');
        document.getElementById('date').textContent=d.toLocaleDateString('en-GB',{weekday:'long',day:'numeric',month:'long'});}
      setInterval(tick,1000);tick();
      function load(){fetch('data.json?'+Date.now()).then(function(r){return r.json();}).then(function(j){
        document.getElementById('stats').innerHTML=j.stats.map(function(s){
          return '<div class="stat"><span>'+s[0]+'</span><span class="v">'+s[1]+'</span></div>';}).join("");
        document.getElementById('plan').innerHTML=j.plan;}).catch(function(){});}
      setInterval(load,2000);load();
    </script></body></html>
  '';

  # writes data.json (stats + colorized public plan) into outDir every few seconds.
  updater = pkgs.writeShellScript "coral-dashboard-updater" ''
    set -u
    out="${outDir}"
    plan_txt="${config.home.homeDirectory}/plan/plan.txt"
    ${pkgs.coreutils}/bin/mkdir -p "$out"
    while :; do
      up=$(${pkgs.coreutils}/bin/uptime | ${pkgs.gnused}/bin/sed 's/.*up //; s/, *[0-9]* user.*//; s/^ *//')
      load=$(${pkgs.coreutils}/bin/uptime | ${pkgs.gnused}/bin/sed 's/.*averages*: //')
      host=$(/usr/sbin/scutil --get LocalHostName 2>/dev/null || echo coral)
      disk=$(${pkgs.coreutils}/bin/df -h / 2>/dev/null | ${pkgs.gnugrep}/bin/grep -v Filesystem | ${pkgs.gawk}/bin/awk '{print $4" free"}')
      mem=$(/usr/bin/vm_stat 2>/dev/null | ${pkgs.gawk}/bin/awk '/page size of/{ps=$8} /Pages active/{a=$3} /Pages wired/{w=$4} END{printf "%.1f GB active", (a+w)*ps/1073741824}')
      # colorize the PUBLIC plan into html spans; %hidden dropped as a safety net.
      if [ -f "$plan_txt" ]; then
        plan=$(${pkgs.gawk}/bin/awk '
          /%hidden/{next}
          /^▶/{print "<span class=doing>" $0 "</span>";next}
          /^▷/{print "<span class=next>" $0 "</span>";next}
          /^✓/{print "<span class=done>" $0 "</span>";next}
          /^~/{print "<span class=done>" $0 "</span>";next}
          {print "<span>" $0 "</span>"}' "$plan_txt")
      else
        plan="(plan not synced to this box yet)"
      fi
      ${pkgs.jq}/bin/jq -n \
        --arg host "$host" --arg up "$up" --arg load "$load" --arg disk "$disk" --arg mem "$mem" --arg plan "$plan" \
        '{stats:[["host",$host],["uptime",$up],["load",$load],["memory",$mem],["disk",$disk]],plan:$plan}' \
        > "$out/.data.json.tmp" && ${pkgs.coreutils}/bin/mv "$out/.data.json.tmp" "$out/data.json"
      ${pkgs.coreutils}/bin/sleep 3
    done
  '';

  watcher = pkgs.writeShellScript "dashboard-watcher" ''
    set -u
    IOREG="/usr/sbin/ioreg"
    GREP="${pkgs.gnugrep}/bin/grep"
    AWK="${pkgs.gawk}/bin/awk"
    PGREP="${pkgs.procps}/bin/pgrep"
    PKILL="${pkgs.procps}/bin/pkill"
    SLEEP="${pkgs.coreutils}/bin/sleep"
    DATE="${pkgs.coreutils}/bin/date"
    CP="${pkgs.coreutils}/bin/cp"
    MKDIR="${pkgs.coreutils}/bin/mkdir"

    THRESHOLD=${toString cfg.idleSeconds}
    POLL=${toString cfg.pollSeconds}
    COOLDOWN=90
    last_launch=0
    out="${outDir}"
    profile="${profileDir}"
    TAG="coral-dashboard-kiosk"   # unique --user-data-dir suffix used as the process tag

    idle_seconds() {
      "$IOREG" -c IOHIDSystem 2>/dev/null | "$GREP" '"HIDIdleTime"' \
        | "$AWK" '{ for (i=1;i<=NF;i++) if ($i+0==$i){v=$i;break} if(min==""||v<min)min=v }
                  END { if(min=="")print 0; else printf "%d\n", min/1000000000 }'
    }
    kiosk_running() { "$PGREP" -f "$TAG" >/dev/null 2>&1; }

    start_kiosk() {
      # single-instance: kill any stray kiosk + its updater first.
      "$PKILL" -f "$TAG" >/dev/null 2>&1 || true
      "$PKILL" -f coral-dashboard-updater >/dev/null 2>&1 || true
      "$MKDIR" -p "$out"
      "$CP" -f "${htmlFile}" "$out/index.html"
      # updater feeds data.json; backgrounded, the watcher persists so it is not HUP'd.
      "${updater}" >/dev/null 2>&1 &
      # `open` foregrounds + Chromium --start-fullscreen fullscreens. the --user-data-dir is $TAG so
      # pgrep/pkill match exactly this kiosk and never a real browser window.
      # --start-fullscreen (NOT --kiosk): fullscreen but Cmd+Q/Cmd+W always work as a
      # guaranteed manual exit, so it can never trap the screen. the watcher also
      # auto-dismisses on input below.
      /usr/bin/open -na Chromium --args \
        --app="file://$out/index.html" --start-fullscreen \
        --user-data-dir="$profile-$TAG" \
        --allow-file-access-from-files --no-first-run --no-default-browser-check \
        --disable-infobars --disable-translate --noerrdialogs --disable-session-crashed-bubble \
        >/dev/null 2>&1 &
    }
    stop_kiosk() {
      "$PKILL" -f "$TAG" >/dev/null 2>&1 || true
      "$PKILL" -f "coral-dashboard/index.html" >/dev/null 2>&1 || true
      "$PKILL" -f coral-dashboard-updater >/dev/null 2>&1 || true
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
in
{
  options.rice.dashboard = {
    enable = lib.mkEnableOption "AFK-only external-display dashboard (Chromium kiosk)";
    idleSeconds = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = "Seconds of no HID input before the dashboard is shown.";
    };
    pollSeconds = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "How often the watcher samples HID idle time.";
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.agents.dashboard = {
      enable = true;
      config = {
        ProgramArguments = [ "${watcher}" ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Background";
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/dashboard.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/dashboard.log";
      };
    };
  };
}
