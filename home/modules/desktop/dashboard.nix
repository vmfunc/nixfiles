# coral AFK dashboard, as a macOS screen saver.
#
# WHY a screen saver (not a kiosk window, not a wallpaper PNG): a screen saver is
# the only surface that (a) animates, (b) appears automatically when the box is
# idle, and (c) draws over the LOCK screen. a wallpaper can't animate; a normal
# app window can't draw once the session is locked. so the animated WebGL
# dashboard lives in a .saver bundle that hosts a WKWebView.
#
# RENDER PATH: CoralDash.saver (an ObjC ScreenSaverView) hosts a WKWebView that
# loads http://127.0.0.1:PORT/. loopback, not file://, so the legacyScreenSaver
# sandbox can read it and the page can fetch data.json same-origin. a launchd
# agent serves that dir and refreshes data.json. the WebGL shader animates itself
# via requestAnimationFrame inside the page.
#
# OPSEC, SHARED OFFICE: the page shows non-sensitive content only -- clock,
# system stats, and the PUBLIC .plan (%hidden lines dropped). the host config
# still requires the password on wake.
#
# SIGNING: macOS 26 / arm64 will not load an unsigned .saver, so the bundle is
# ad-hoc signed at install time. selecting it as the active saver the first time
# may still need a one-time approval in System Settings.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.dashboard;

  # loopback port. hardcoded here AND in coral-dash.m; keep the two in sync.
  port = 8765;

  appSupport = "${config.home.homeDirectory}/Library/Application Support/coral-dash";
  saversDir = "${config.home.homeDirectory}/Library/Screen Savers";

  # serves appSupport on loopback and runs the data updater. KeepAlive on the
  # agent guards the pair: if either dies the script exits and launchd respawns.
  serverScript = pkgs.writeShellScript "coral-dash-server" ''
    set -u
    dir="${appSupport}"
    ${pkgs.coreutils}/bin/mkdir -p "$dir"
    ${pkgs.python3}/bin/python3 "$dir/updater.py" &
    updater_pid=$!
    trap '${pkgs.coreutils}/bin/kill "$updater_pid" 2>/dev/null || true' EXIT
    exec ${pkgs.python3}/bin/python3 -m http.server ${toString port} \
      --bind 127.0.0.1 --directory "$dir"
  '';
in
{
  options.rice.dashboard = {
    enable = lib.mkEnableOption "AFK dashboard screen saver (animated WebGL, shows on lock)";
    idleSeconds = lib.mkOption {
      type = lib.types.int;
      default = 180;
      description = "Seconds of inactivity before the dashboard screen saver engages.";
    };
  };

  config = lib.mkIf cfg.enable {
    # the page + the data updater live in a writable app-support dir so the
    # updater can drop data.json beside index.html for same-origin fetches.
    home.file."Library/Application Support/coral-dash/index.html".source = ./coral-dash/index.html;
    home.file."Library/Application Support/coral-dash/updater.py".source = ./coral-dash/updater.py;

    # loopback server + updater. RunAtLoad so it is up before the saver needs it.
    launchd.agents.coral-dash-server = {
      enable = true;
      config = {
        ProgramArguments = [ "${serverScript}" ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Background";
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/coral-dash.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/coral-dash.log";
      };
    };

    # build + install + sign the .saver, then select it as the active screen
    # saver. the compile uses the system clang (CLT) rather than a nix derivation
    # because the ScreenSaver framework lives in the macOS SDK; `|| true` keeps a
    # missing-CLT box from aborting activation (the previously installed saver
    # stays). this runs fine headlessly over SSH (no GUI needed to compile).
    home.activation.coralDashSaver = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      saver="${saversDir}/CoralDash.saver"
      run ${pkgs.coreutils}/bin/mkdir -p "$saver/Contents/MacOS"
      run ${pkgs.coreutils}/bin/cp -f "${./coral-dash/Info.plist}" "$saver/Contents/Info.plist"
      if [ -x /usr/bin/clang ]; then
        run /usr/bin/clang -bundle -fobjc-arc -O2 \
          -framework ScreenSaver -framework WebKit -framework Cocoa \
          "${./coral-dash/coral-dash.m}" -o "$saver/Contents/MacOS/CoralDash" || true
        run /usr/bin/codesign -s - --force --deep "$saver" || true
      fi
      # select CoralDash + set the idle threshold (per-host screen saver prefs).
      run /usr/bin/defaults -currentHost write com.apple.screensaver moduleDict -dict \
        moduleName -string "CoralDash" path -string "$saver" type -int 0 || true
      run /usr/bin/defaults -currentHost write com.apple.screensaver idleTime -int ${toString cfg.idleSeconds} || true
    '';
  };
}
