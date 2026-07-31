# rice.care: soft recurring nudges (water, food, stretch, meds) as systemd user
# timers. deliberately NOT the `remind` store, which is for dated one-off tasks
# azzie adds by hand; these are standing care, and they never accumulate a
# backlog to feel guilty about.
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
      notify-send --app-name=care --icon=dialog-information \
        "$title" "''${lines[$((RANDOM % ''${#lines[@]}))]}"
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

  serviceFor = kind: {
    Unit.Description = "soft ${kind} nudge";
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe nudge} ${kind}";
    };
  };
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
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ nudge ];

    systemd.user.services =
      lib.mapAttrs' (kind: _: lib.nameValuePair "care-${kind}" (serviceFor kind)) recurring
      // lib.optionalAttrs (cfg.medsTimes != [ ]) { care-meds = serviceFor "meds"; };

    systemd.user.timers =
      timerUnits
      // lib.optionalAttrs (cfg.medsTimes != [ ]) {
        care-meds = {
          Unit.Description = "meds nudge";
          Timer = {
            OnCalendar = cfg.medsTimes;
            # a missed dose is worth a late reminder, unlike a missed water break.
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
  };
}
