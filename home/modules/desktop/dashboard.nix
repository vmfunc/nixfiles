# AFK-only external-display dashboard kiosk.
#
# coral is a clamshell desk machine (external display) as well as the always-on box, so a
# dashboard that pops up mid-typing would be hostile. the watcher only raises the kiosk
# once the machine has been idle (no HID input) for rice.dashboard.idleSeconds, and tears
# it down the instant a key/mouse event lands, dropping straight back to the real desktop.
#
# OPSEC, SHARED OFFICE: the dashboard is eye-candy on a screen anyone can walk past, so
# its content is DELIBERATELY non-sensitive: system stats, an audio visualiser, a clock,
# and the PUBLIC .plan ONLY. the public plan is plan.txt, which `plan publish` writes by
# stripping every %hidden line (it refuses to publish if one leaks); %hidden is ALSO
# re-filtered at render as a belt-and-suspenders net. NEVER read ~/plan/.plan (the master
# file still holds %hidden lines). nothing else that exposes work state: no mesh roster, no
# CI status, no mail, no project names, no terminals with history. do not add such panes.
#
# this is NOT a security boundary. the real lock is the OS screensaver
# (screensaver.askForPassword in hosts/coral) which fires at a LONGER idle. the flow is:
#   active desktop  ->  (idle idleSeconds, default 5m)  dashboard kiosk
#                   ->  (idle ~20m, OS screensaver)     locked, password required
# the kiosk just fills the gap so a clamshell external display shows something tasteful
# instead of the last open window while the desk is empty.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.dashboard;

  # non-sensitive panes only. see the opsec note at the top of this file before editing.
  # peaclock = big centred clock+date; btop = read-only system stats; cava = audio
  # visualiser; planView = the PUBLIC plan (plan.txt, %hidden re-filtered). none of these
  # expose private project state, history, or identity.
  #
  # peaclock, not tty-clock: tty-clock is marked broken in the pinned nixpkgs, so referencing
  # it hard-aborts evaluation. peaclock is the maintained centred-terminal-clock equivalent.

  # public-plan viewer. reads ONLY plan.txt (the %hidden-stripped artifact `plan publish`
  # produces) and re-greps %hidden out as a safety net, so a hidden line can never reach the
  # shared-office screen even if plan.txt were stale. refreshes every 30s; shows a
  # placeholder (never an error) if the plan repo is not on the box yet.
  planView = pkgs.writeShellScript "dashboard-plan" ''
    set -u
    plan_txt="${config.home.homeDirectory}/plan/plan.txt"
    while :; do
      printf '\033[2J\033[H'
      printf '\033[1;38;5;183m  .plan (public)\033[0m\n\n'
      if [ -f "$plan_txt" ]; then
        "${pkgs.gnugrep}/bin/grep" -v '%hidden' "$plan_txt" || true
      else
        printf '  (plan not synced to this box yet)\n'
      fi
      "${pkgs.coreutils}/bin/sleep" 30
    done
  '';

  # robust clock pane: peaclock errors ("facet local name not valid") and
  # tty-clock/figlet are unavailable, so render time/date with a dependency-free loop.
  clockView = pkgs.writeShellScript "dashboard-clock" ''
    while :; do
      printf '\033[2J\033[H\n\n\n'
      printf '   \033[1;38;5;183m%s\033[0m\n' "$(${pkgs.coreutils}/bin/date '+%H:%M:%S')"
      printf '   \033[38;5;151m%s\033[0m\n' "$(${pkgs.coreutils}/bin/date '+%A %d %B')"
      ${pkgs.coreutils}/bin/sleep 1
    done
  '';

  # system-info pane (non-sensitive). replaces cava, which needs a pulseaudio/mic
  # backend that does not exist on macos.
  sysView = pkgs.writeShellScript "dashboard-sys" ''
    while :; do
      printf '\033[2J\033[H'
      ${pkgs.fastfetch}/bin/fastfetch 2>/dev/null || true
      ${pkgs.coreutils}/bin/sleep 30
    done
  '';

  # kiosk zellij config: suppress the first-run welcome/tips + release notes and
  # drop pane frames so the layout fills the screen instead of a setup screen.
  kioskZellij = pkgs.writeText "kiosk-zellij.kdl" ''
    show_startup_tips false
    show_release_notes false
    pane_frames false
    mouse_mode false
  '';

  dashboardLayout = pkgs.writeText "dashboard.kdl" ''
    layout {
        pane split_direction="vertical" {
            pane size="55%" {
                command "${pkgs.btop}/bin/btop"
            }
            pane split_direction="horizontal" {
                pane size="28%" {
                    command "${clockView}"
                }
                pane {
                    command "${planView}"
                }
                pane size="36%" {
                    command "${sysView}"
                }
            }
        }
    }
  '';

  # dedicated wezterm config for the kiosk: a gui-startup handler that spawns the zellij
  # dashboard and toggles the window to fullscreen. wezterm has no clean `start --fullscreen`
  # CLI flag, so the supported path is a config-file `gui-startup` event that owns the spawn
  # and calls window:toggle_fullscreen() on the resulting window. front_end OpenGL avoids the
  # WebGpu init flakiness when launched headless-of-a-foreground-app from launchd.
  #
  # this config inherits nothing from the main wezterm.lua (passed via --config-file), so
  # the kiosk is a clean, predictable surface, no leader keys, no shells, just the layout.
  kioskWeztermConfig = pkgs.writeText "wezterm-dashboard.lua" ''
    local wezterm = require 'wezterm'
    local config = wezterm.config_builder()

    config.color_scheme = 'Catppuccin ${
      (lib.toUpper (builtins.substring 0 1 config.rice.theme.flavor))
      + (builtins.substring 1 (builtins.stringLength config.rice.theme.flavor) config.rice.theme.flavor)
    }'
    config.font = wezterm.font_with_fallback { 'JetBrainsMono Nerd Font', 'Symbols Nerd Font' }
    config.font_size = 16.0
    config.enable_tab_bar = false
    config.window_padding = { left = 0, right = 0, top = 0, bottom = 0 }
    config.window_decorations = 'NONE'
    config.audible_bell = 'Disabled'
    -- launched from a background launchd agent; WebGpu can fail to init that way.
    config.front_end = 'OpenGL'

    -- own the spawn so we can fullscreen the window the kiosk runs in. attaches the
    -- zellij dashboard session driven by the non-sensitive layout above.
    wezterm.on('gui-startup', function(cmd)
      local args = {
        '${pkgs.zellij}/bin/zellij',
        '--config', '${kioskZellij}',
        '--layout', '${dashboardLayout}',
        'attach', '--create', 'dashboard',
      }
      local _, _, window = wezterm.mux.spawn_window { args = args }
      -- delay the fullscreen toggle so the window is realized before it fires;
      -- otherwise the tiling wm grabs it first and it ends up tiled behind
      -- other windows instead of a fullscreen kiosk on its own space.
      wezterm.time.call_after(0.6, function()
        window:gui_window():toggle_fullscreen()
      end)
    end)

    return config
  '';

  # idle watcher. reads HID idle from ioreg (IOHIDSystem's HIDIdleTime is nanoseconds since
  # the last input event), and crosses it against the threshold to raise/tear-down the kiosk.
  # absolute store paths only so it does not depend on the launchd agent's PATH.
  watcher = pkgs.writeShellScript "dashboard-watcher" ''
    set -u

    IOREG="/usr/sbin/ioreg"
    GREP="${pkgs.gnugrep}/bin/grep"
    AWK="${pkgs.gawk}/bin/awk"
    PGREP="${pkgs.procps}/bin/pgrep"
    PKILL="${pkgs.procps}/bin/pkill"
    SLEEP="${pkgs.coreutils}/bin/sleep"
    WEZTERM="/etc/profiles/per-user/${config.home.username}/bin/wezterm"

    THRESHOLD=${toString cfg.idleSeconds}
    POLL=${toString cfg.pollSeconds}

    # the kiosk's --config-file is a unique store path used by NOTHING else, so it is the
    # natural process tag: pgrep/pkill -f on it matches exactly the kiosk wezterm and never
    # the real wezterm windows (which use the main wezterm.lua).
    KIOSK_TAG="${kioskWeztermConfig}"

    idle_seconds() {
      # HIDIdleTime is reported per HID device; the SMALLEST value is the true system idle
      # (any active device resets it). nanoseconds -> integer seconds.
      "$IOREG" -c IOHIDSystem 2>/dev/null \
        | "$GREP" '"HIDIdleTime"' \
        | "$AWK" '{ for (i=1;i<=NF;i++) if ($i+0==$i) { v=$i; break }
                    if (min==""||v<min) min=v }
                  END { if (min=="") print 0; else printf "%d\n", min/1000000000 }'
    }

    kiosk_running() {
      "$PGREP" -f "$KIOSK_TAG" >/dev/null 2>&1
    }

    start_kiosk() {
      # --always-new-process forces THIS invocation to own the GUI so our --config-file (and
      # its gui-startup fullscreen handler) actually applies, instead of being handed off to
      # an already-running wezterm. backgrounded so the watcher loop keeps polling.
      "$WEZTERM" --config-file "${kioskWeztermConfig}" \
        start --always-new-process >/dev/null 2>&1 &
    }

    stop_kiosk() {
      # kill only the tagged kiosk; the zellij/btop/cava children die with the session.
      "$PKILL" -f "$KIOSK_TAG" >/dev/null 2>&1 || true
    }

    # main loop: poll, not busy-spin. robust to the kiosk being closed by hand (re-check
    # kiosk_running every tick rather than tracking our own state).
    while :; do
      idle="$(idle_seconds)"
      # guard against an empty / non-numeric ioreg hiccup; treat as "active" (idle 0) so a
      # parse glitch never wrongly raises the kiosk over an active session.
      if [ -z "$idle" ] || ! [ "$idle" -eq "$idle" ] 2>/dev/null; then
        idle=0
      fi

      if [ "$idle" -ge "$THRESHOLD" ]; then
        kiosk_running || start_kiosk
      else
        # input within the threshold: drop the kiosk if it is up.
        kiosk_running && stop_kiosk
      fi

      "$SLEEP" "$POLL"
    done
  '';
in
{
  options.rice.dashboard = {
    enable = lib.mkEnableOption "AFK-only external-display dashboard kiosk";

    idleSeconds = lib.mkOption {
      type = lib.types.int;
      default = 300;
      description = ''
        Seconds of no HID input before the dashboard kiosk is raised. Keep this WELL below
        the OS screensaver idle (hosts/coral screensaver.askForPassword) so the order is
        dashboard-first, lock-later. The dashboard is eye-candy, not a security boundary.
      '';
    };

    pollSeconds = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "How often the watcher samples HID idle time. 3-5s keeps it responsive without busy-spinning.";
    };
  };

  config = lib.mkIf cfg.enable {
    # long-running watcher, same agent idiom as autoraise: RunAtLoad + KeepAlive so it is
    # always present, ProcessType Background so it stays out of the foreground scheduler.
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
