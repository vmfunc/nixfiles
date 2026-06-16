# AFK-only external-display dashboard kiosk.
#
# quaver physically works at coral in the office (external display, clamshell), so a
# dashboard that pops up while she is typing would be hostile. this agent only raises
# the kiosk once the machine has been idle (no HID input) for rice.dashboard.idleSeconds,
# and tears it down the instant she touches the keyboard/mouse, dropping her straight
# back to her real desktop.
#
# OPSEC, SHARED OFFICE: the dashboard is eye-candy on a screen anyone can walk past, so
# its content is DELIBERATELY non-sensitive only -- system stats, an audio visualiser, a
# clock. NOTHING that reveals her work: no .plan, no mesh roster, no CI status, no mail,
# no project names, no terminals with history. do not add such panes here.
#
# this is NOT a security boundary. the real lock is the OS screensaver
# (screensaver.askForPassword in hosts/coral) which fires at a LONGER idle. the flow is:
#   active desktop  ->  (idle idleSeconds, default 5m)  dashboard kiosk
#                   ->  (idle ~20m, OS screensaver)     locked, password required
# the kiosk is just what fills the gap so a clamshell-driven external display shows
# something pretty instead of her last open window while she steps away.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.dashboard;

  # non-sensitive panes only. see the opsec note at the top of this file before editing.
  # tty-clock gives a big centred clock+date; btop is read-only system stats; cava is an
  # audio visualiser. none of these expose project state, history, or identity.
  dashboardLayout = pkgs.writeText "dashboard.kdl" ''
    layout {
        pane split_direction="vertical" {
            pane size="60%" {
                command "${pkgs.btop}/bin/btop"
            }
            pane split_direction="horizontal" {
                pane {
                    // -c centre, -C accent colour (6=cyan), -s show seconds, -D date line
                    command "${pkgs.tty-clock}/bin/tty-clock"
                    args "-c" "-C" "6" "-s" "-D"
                }
                pane {
                    command "${pkgs.cava}/bin/cava"
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
  # this config inherits nothing from the user's main wezterm.lua (we pass --config-file), so
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
        '--layout', '${dashboardLayout}',
        'attach', '--create', 'dashboard',
      }
      local _, _, window = wezterm.mux.spawn_window { args = args }
      window:gui_window():toggle_fullscreen()
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
    # the user's real wezterm windows (which use her main wezterm.lua).
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
      # her already-running wezterm. backgrounded so the watcher loop keeps polling.
      "$WEZTERM" --config-file "${kioskWeztermConfig}" \
        start --always-new-process >/dev/null 2>&1 &
    }

    stop_kiosk() {
      # kill only the tagged kiosk; the zellij/btop/cava children die with the session.
      "$PKILL" -f "$KIOSK_TAG" >/dev/null 2>&1 || true
    }

    # main loop: poll, not busy-spin. robust to the kiosk being closed by hand (we re-check
    # kiosk_running every tick rather than tracking our own state).
    while :; do
      idle="$(idle_seconds)"
      # guard against an empty / non-numeric ioreg hiccup; treat as "active" (idle 0) so a
      # parse glitch never wrongly raises the kiosk over her shoulder.
      if [ -z "$idle" ] || ! [ "$idle" -eq "$idle" ] 2>/dev/null; then
        idle=0
      fi

      if [ "$idle" -ge "$THRESHOLD" ]; then
        kiosk_running || start_kiosk
      else
        # she is back (input within the threshold): drop the kiosk if it is up.
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
