# rice.care: soft recurring nudges (water, food, stretch, meds) as systemd user
# timers. deliberately NOT the `remind` store, which is for dated one-off tasks
# azzie adds by hand; these are standing care, and they never accumulate a
# backlog to feel guilty about.
#
# meds are special: they nag every rice.care.medsNagMinutes until acknowledged
# (`meds-taken`, or a click on the notification), because a dose that scrolls
# past unnoticed is the whole failure mode.
#
# wording is picked at random from a small pool per kind so it reads like a
# person and not a cron job. `cozy` puts mako in do-not-disturb, so a wind-down
# silences these for free.
# cross-file deps: mako.nix owns the notification daemon; cozy.nix silences it.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.care;

  nudge = pkgs.writeShellApplication {
    name = "care-nudge";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.coreutils
    ];
    text = ''
      kind="''${1:-water}"
      mode="''${2:-once}"

      # meds are the one nudge that keeps asking, so it needs a pending marker.
      # runtime dir, not state: a dose that was pending across a reboot is stale,
      # and the next OnCalendar shot will ask again anyway.
      pending="''${XDG_RUNTIME_DIR:-/tmp}/care-meds-pending"
      # a hair under the nag interval, so one notification is always retired
      # before the next fires and they cannot stack up.
      wait_secs=${toString (cfg.medsNagMinutes * 60 - 30)}

      case "$kind" in
        water)
          title="water break"
          lines=(
            "little sip for me, petal?"
            "glass of water, then back to it."
            "hydrate, love. it takes ten seconds."
          )
          ;;
        food)
          title="food check"
          lines=(
            "when did you last eat, sweetpea?"
            "something small counts. toast is a meal."
            "feed the little one, please."
          )
          ;;
        stretch)
          title="stretch"
          lines=(
            "shoulders down, jaw unclenched."
            "stand up for a moment, i'll wait."
            "look at something far away for a bit."
          )
          ;;
        meds)
          title="meds"
          lines=(
            "meds time, hun."
            "pills, then i'll stop bothering you."
            "meds, love. i'm right here."
          )
          ;;
        *)
          echo "unknown nudge: $kind" >&2
          exit 2
          ;;
      esac

      # $RANDOM is plenty for picking a phrase, and keeps this dependency-free.
      line="''${lines[$((RANDOM % ''${#lines[@]}))]}"

      if [ "$kind" != meds ]; then
        notify-send --app-name=care --icon=dialog-information "$title" "$line"
        exit 0
      fi

      case "$mode" in
        # a new dose came due. an older pending dose is simply replaced: nagging
        # about two at once helps nobody.
        start) date +%s > "$pending" ;;
        ack)
          rm -f "$pending"
          notify-send --app-name=care "thank you, love" "that's one less thing to hold."
          exit 0
          ;;
        nag) [ -f "$pending" ] || exit 0 ;;
        *)
          echo "unknown meds mode: $mode" >&2
          exit 2
          ;;
      esac

      # critical so mako never expires it on its own, and the action lets a plain
      # left-click count as "taken" (mako invokes the `default` action on click).
      # notify-send blocks while the action is live, hence the timeout.
      answer="$(timeout "$wait_secs" notify-send --app-name=care --urgency=critical \
        --action=default="i took them" "$title" "$line" || true)"

      if [ "$answer" = default ]; then
        rm -f "$pending"
        notify-send --app-name=care "thank you, love" "that's one less thing to hold."
      fi
    '';
  };

  # every recurring kind is the same unit pair, so build them from one shape.
  timerUnits = lib.mapAttrs' (
    kind: interval:
    lib.nameValuePair "care-${kind}" {
      Unit.Description = "soft ${kind} nudge";
      Timer = {
        # not at login: the first thing after boot should not be a chore.
        OnBootSec = "20m";
        OnUnitActiveSec = interval;
        Persistent = false;
      };
      Install.WantedBy = [ "timers.target" ];
    }
  ) recurring;

  recurring = lib.filterAttrs (_: v: v != null) {
    water = cfg.waterInterval;
    food = cfg.foodInterval;
    stretch = cfg.stretchInterval;
  };

  serviceFor = kind: args: {
    Unit.Description = "soft ${kind} nudge";
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe nudge} ${kind} ${args}";
    };
  };

  # what azzie types (or clicks) to stop the asking.
  medsTaken = pkgs.writeShellApplication {
    name = "meds-taken";
    text = "exec ${lib.getExe nudge} meds ack";
  };

  medsEnabled = cfg.medsTimes != [ ];
in
{
  options.rice.care = {
    enable = lib.mkEnableOption "soft recurring care nudges";

    waterInterval = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "45m";
      description = "systemd time span between water nudges. Null disables them.";
    };

    foodInterval = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "3h";
      description = "systemd time span between food nudges. Null disables them.";
    };

    stretchInterval = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "90m";
      description = "systemd time span between stretch nudges. Null disables them.";
    };

    medsTimes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "09:00"
        "21:00"
      ];
      description = ''
        Wall-clock times for the meds nudge, as systemd OnCalendar values.
        Empty = no meds timer. Missed ones fire late on wake (Persistent).
      '';
    };

    medsNagMinutes = lib.mkOption {
      type = lib.types.ints.between 2 120;
      default = 10;
      description = ''
        How often the meds nudge asks again while a dose is unacknowledged. It
        never gives up on its own: a dose silently dropped after N tries is the
        exact failure this exists to prevent. Clear it with `meds-taken` or by
        clicking the notification.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ nudge ] ++ lib.optional medsEnabled medsTaken;

    systemd.user.services =
      lib.mapAttrs' (kind: _: lib.nameValuePair "care-${kind}" (serviceFor kind "once")) recurring
      // lib.optionalAttrs medsEnabled {
        care-meds = serviceFor "meds" "start";
        care-meds-nag = serviceFor "meds" "nag";
      };

    systemd.user.timers =
      timerUnits
      // lib.optionalAttrs medsEnabled {
        care-meds = {
          Unit.Description = "meds nudge";
          Timer = {
            OnCalendar = cfg.medsTimes;
            # a missed dose is worth a late reminder, unlike a missed water break.
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };
        # the nag runs on a plain interval and no-ops unless a dose is pending,
        # which keeps "keep asking" out of the dose timer's calendar logic.
        care-meds-nag = {
          Unit.Description = "meds nudge, again";
          Timer = {
            OnBootSec = "${toString cfg.medsNagMinutes}m";
            OnUnitActiveSec = "${toString cfg.medsNagMinutes}m";
            Persistent = false;
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
  };
}
