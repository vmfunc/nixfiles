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

  sounds = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo";

  nudge = pkgs.writeShellApplication {
    name = "care-nudge";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.coreutils
      pkgs.pipewire # pw-play
      pkgs.mako # makoctl, to stay quiet while cozy
    ];
    text = ''
      kind="''${1:-water}"
      mode="''${2:-once}"

      # meds are the one nudge that keeps asking, so it needs a pending marker.
      # runtime dir, not state: a dose that was pending across a reboot is stale,
      # and the next OnCalendar shot will ask again anyway.
      pending="''${XDG_RUNTIME_DIR:-/tmp}/care-meds-pending"
      # the hydration count shares the soft set's data dir, one file per day, so
      # yesterday's count is never silently carried forward.
      water_file="''${XDG_DATA_HOME:-$HOME/.local/share}/soft/water-$(date +%Y-%m-%d)"

      # do-not-disturb hides the popup, so a chime would be a notification that
      # dodges the mode. `cozy` sets it, and cozy means quiet.
      chime() {
        makoctl mode 2>/dev/null | grep -qx do-not-disturb && return 0
        pw-play --volume=${toString cfg.volume} "${sounds}/$1.oga" 2>/dev/null || true
      }

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
        hour)
          # no message pool: the whole point is that it is the same small sound
          # every hour, so it stops registering as an interruption.
          chime bell
          notify-send --app-name=care --urgency=low "$(date +%H:%M)" "just the hour, love."
          exit 0
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

      sip() {
        mkdir -p "$(dirname "$water_file")"
        count=$(( $(cat "$water_file" 2>/dev/null || echo 0) + 1 ))
        echo "$count" > "$water_file"
      }

      # durable ack trail (one file per kind per day, HH:MM per line): the
      # pending marker is volatile by design, but "took meds at 13:02" and
      # "ate at 19:40" belong to the day's record. daylog-harvest reads these.
      ack_log() {
        f="''${XDG_DATA_HOME:-$HOME/.local/share}/soft/$1-$(date +%Y-%m-%d)"
        mkdir -p "$(dirname "$f")"
        date +%H:%M >> "$f"
      }

      # `care-nudge water sip` is what the bar cell and the `sip` command call.
      if [ "$kind" = water ] && [ "$mode" = sip ]; then
        sip
        exit 0
      fi

      if [ "$kind" = water ]; then
        chime message
        # two minutes of clickable, not the whole 45: the notification should be
        # gone by the time the next one arrives either way.
        answer="$(timeout 120 notify-send --app-name=care --icon=dialog-information \
          --action=default="had some" "$title" "$line" || true)"
        [ "$answer" = default ] && sip
        exit 0
      fi

      # `care-nudge food ack` is what the `fed` command calls; the nudge's own
      # click lands here too via the action below.
      if [ "$kind" = food ] && [ "$mode" = ack ]; then
        ack_log food
        exit 0
      fi

      if [ "$kind" = food ]; then
        chime message
        answer="$(timeout 120 notify-send --app-name=care --icon=dialog-information \
          --action=default="i ate" "$title" "$line" || true)"
        [ "$answer" = default ] && ack_log food
        exit 0
      fi

      if [ "$kind" != meds ]; then
        chime message
        notify-send --app-name=care --icon=dialog-information "$title" "$line"
        exit 0
      fi

      case "$mode" in
        # a new dose came due. an older pending dose is simply replaced: nagging
        # about two at once helps nobody.
        start) date +%s > "$pending" ;;
        ack)
          rm -f "$pending"
          ack_log meds
          chime complete
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
      # bell, not alarm-clock-elapsed: this should carry across a room without
      # sounding like something has gone wrong.
      chime bell
      answer="$(timeout "$wait_secs" notify-send --app-name=care --urgency=critical \
        --action=default="i took them" "$title" "$line" || true)"

      if [ "$answer" = default ]; then
        rm -f "$pending"
        ack_log meds
        chime complete
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

  # counts a glass without waiting to be asked.
  sip = pkgs.writeShellApplication {
    name = "sip";
    text = "exec ${lib.getExe nudge} water sip";
  };

  # logs a meal without waiting to be asked, `sip`'s plate-shaped sibling.
  fed = pkgs.writeShellApplication {
    name = "fed";
    text = "exec ${lib.getExe nudge} food ack";
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

    volume = lib.mkOption {
      type = lib.types.numbers.between 0.0 1.0;
      default = 0.4;
      description = "Chime volume, linear, as pw-play takes it. 0 mutes the nudges.";
    };

    hourlyChime = lib.mkEnableOption "a soft chime and the time, on the hour";

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
    home.packages = [
      nudge
      sip
      fed
    ]
    ++ lib.optional medsEnabled medsTaken;

    systemd.user.services =
      lib.mapAttrs' (kind: _: lib.nameValuePair "care-${kind}" (serviceFor kind "once")) recurring
      // lib.optionalAttrs medsEnabled {
        care-meds = serviceFor "meds" "start";
        care-meds-nag = serviceFor "meds" "nag";
      }
      // lib.optionalAttrs cfg.hourlyChime { care-hour = serviceFor "hour" "once"; };

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
        # ON THE HOUR, not every 60 minutes from boot: a clock that chimes at
        # 14:23 is just an alarm.
      }
      // lib.optionalAttrs cfg.hourlyChime {
        care-hour = {
          Unit.Description = "the hour";
          Timer = {
            OnCalendar = "hourly";
            Persistent = false;
          };
          Install.WantedBy = [ "timers.target" ];
        };
      }
      // {
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
