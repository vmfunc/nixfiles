# PSO2 auto-attack / photon-art looper, gated behind rice.pso2Macro.enable
# (default OFF, and NOT enabled on any host, azzie flips it herself). opt-in,
# ToS-violating automation, kept off by default and inert until asked for.
#
# WHY host-side ydotool (uinput) and NOT AutoHotkey-in-prefix: injecting at the
# linux kernel /dev/uinput layer is BELOW the wine/proton prefix, so the in-prefix
# anti-cheat (wellbia on current NGS, gameguard on JP classic) cannot see the
# injector, no in-prefix process, no memory access, no hooked API. AHK runs inside
# the same NT namespace the anti-cheat scans, which is the one place it gets
# caught. this is niri/wayland-only (there is no X11 injection path here).
#
# HONEST RISK: the injection is low technical-detection risk, but automation is a
# ToS violation regardless; the ban vector is behavioral (metronome timing,
# superhuman uptime, player reports), which the jittered loop + focus-gate blunt
# but do not erase. solo/attended/short sessions only. see docs/gaming.md.
#
# PUBLIC-MIRROR NOTE: this tree mirrors to git.collar.sh world-readable, so this
# file names ToS-violating automation under azzie's handle. decide before pushing
# whether that belongs in the public tree (rename / private overlay / drop).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.pso2Macro;

  # the loop lives in a writeShellApplication so shellcheck runs at build and the
  # runtime deps (niri IPC, ydotool, jq, notify) are on a clean PATH. niri msg is
  # the wayland-native focus gate; without niri in runtimeInputs the gate crashes
  # under set -u. keycodes are raw linux KEY_* event codes, NOT chars.
  pso2-attack-loop = pkgs.writeShellApplication {
    name = "pso2-attack-loop";
    runtimeInputs = [
      config.programs.niri.package
      pkgs.ydotool
      pkgs.jq
      pkgs.libnotify
    ];
    text = ''
      # opt-in auto-attack / PA looper for PSO2, niri-focus-gated. a second
      # invocation (bound to a hotkey) stops it via the state file. jittered
      # delays on purpose: a perfect metronome is the behavior that gets caught.
      STATE="''${XDG_RUNTIME_DIR:-/tmp}/pso2-loop.on"

      # map these to YOUR in-game binds. 30=KEY_A, 33=KEY_F, 34=KEY_G. find codes
      # with `sudo evtest` or /usr/include/linux/input-event-codes.h.
      ATTACK_KEY=30
      PA_ONE=33
      PA_TWO=34

      # IMPORTANT: run `niri msg --json focused-window` with PSO2 UP and paste its
      # real app_id/title here. if PSO2 runs under gamescope (steam's
      # gamescopeSession), niri sees "gamescope", not the game, and this gate
      # NEVER matches (loop silently idles). launch PSO2 in plain proton
      # (windowed/borderless, no gamescope) so niri gets the real wine app_id.
      PSO2_MATCH='pso2|PHANTASYSTARONLINE2|Phantasy Star'

      if [[ -e "$STATE" ]]; then
        rm -f "$STATE"
        notify-send -t 1500 "PSO2 loop" "stopped" || true
        exit 0
      fi
      : > "$STATE"
      notify-send -t 1500 "PSO2 loop" "started (focus PSO2, not gamescope)" || true

      pso2_focused() {
        niri msg --json focused-window 2>/dev/null \
          | jq -e --arg re "$PSO2_MATCH" \
              '((.app_id // "") + " " + (.title // "")) | test($re; "i")' >/dev/null
      }

      # base ms +/- spread, echoed as seconds for sleep.
      jitter() {
        local b="$1" s="$2" r
        r=$(( b + (RANDOM % (2 * s + 1)) - s ))
        awk -v ms="$r" 'BEGIN { printf "%.3f", ms / 1000 }'
      }

      # press then release one keycode. the daemon inserts its default key-delay
      # between down and up, so each tap already carries a small human-ish hold.
      tap() { ydotool key "$1:1" "$1:0"; }

      while [[ -e "$STATE" ]]; do
        if pso2_focused; then
          tap "$ATTACK_KEY"; sleep "$(jitter 220 60)"
          tap "$ATTACK_KEY"; sleep "$(jitter 220 60)"
          tap "$ATTACK_KEY"; sleep "$(jitter 240 70)"
          tap "$PA_ONE";     sleep "$(jitter 900 180)"
          if (( RANDOM % 3 == 0 )); then
            tap "$PA_TWO";   sleep "$(jitter 900 180)"
          fi
        else
          # not focused: idle-poll, never emit keys into other windows.
          sleep 0.4
        fi
      done
    '';
  };
in
{
  options.rice.pso2Macro.enable = lib.mkEnableOption "PSO2-only ydotool auto-attack macro (opt-in, ToS-violating, off by default)";

  config = lib.mkIf cfg.enable {
    # programs.ydotool.enable is the whole daemon story: it runs ydotoold as a
    # hardened root systemd service (DeviceAllow=/dev/uinput), creates the
    # `ydotool` group, exports YDOTOOL_SOCKET, and puts ydotool on PATH.
    programs.ydotool.enable = true;

    # the module does NOT add the user to the group; without this the ydotool CLI
    # gets EACCES on the daemon socket. TODO(deploy): relogin (or `newgrp ydotool`)
    # after the first switch so the group membership lands in the niri session.
    users.users.quaver.extraGroups = [ "ydotool" ];

    # ensure the uinput node exists at boot (uinput is =m in nixpkgs). NO udev
    # rule: ydotoold runs as root and opens /dev/uinput itself; the user only ever
    # talks to the group-owned socket, whose perms the module already sets.
    boot.kernelModules = [ "uinput" ];

    environment.systemPackages = [
      pkgs.jq
      pkgs.libnotify
      pso2-attack-loop
    ];
  };
}
