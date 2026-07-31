# rice.little: the soft set. `little` / `big` flip the desk (pkgs/little), `hug`
# and a dozen small comfort commands come with them (pkgs/soft).
#
# callPackage against the repo paths rather than pkgs.*: the custom-pkgs overlay
# is darwin-gated, and `little` is wayland/niri-only anyway.
# cross-file deps: theme.nix owns the accent these print in; niri.nix owns the
# compositor whose output scale gets flipped; cozy.nix supplies the `cozy` that
# `tuck` and `sleepy` call through PATH.
{
  config,
  lib,
  pkgs,
  theme,
  ...
}:
let
  cfg = config.rice.little;

  littlePkg = pkgs.callPackage ../../../pkgs/little/package.nix { inherit (cfg) scale; };
  hugPkg = pkgs.callPackage ../../../pkgs/hug/package.nix { inherit (theme) accentHex; };
  softSet = pkgs.callPackage ../../../pkgs/soft/package.nix {
    inherit (cfg) comfortPeople comfortSong;
    inherit (theme) accentHex;
  };

  # one word out, one word back. `little off` works too, but nobody in little
  # space wants to remember a subcommand.
  big = pkgs.writeShellApplication {
    name = "big";
    text = "exec ${lib.getExe littlePkg} off";
  };

  # napWake is scheduled by `nap` and `tuck` through systemd-run, never typed.
  # isDerivation filters out the `override`/`overrideDerivation` functions
  # callPackage staples onto an attrset result.
  commands = lib.filter lib.isDerivation (lib.attrValues (removeAttrs softSet [ "napWake" ]));
in
{
  options.rice.little = {
    enable = lib.mkEnableOption "the `little` / `big` mode flip and the soft command set";

    scale = lib.mkOption {
      type = lib.types.numbers.between 1.0 3.0;
      default = 1.6;
      description = "niri output scale while little. Bigger text, fewer things on screen.";
    };

    comfortPeople = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "sam" ];
      description = ''
        First names `breathe` lists as people worth messaging. WARNING: this repo
        is a public mirror, so whatever goes here is world-readable. Names only,
        never numbers or handles that resolve to an account.
      '';
    };

    comfortSong = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/home/quaver/Music/comfort.flac";
      description = "What `sing` plays. A file path or any URL mpv can open.";
    };

    screentimeHours = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = 6;
      description = ''
        Nudge once an hour after this many hours in one session. Null disables
        the timer. Session start, not machine uptime, so a slept-through night
        does not count.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      littlePkg
      big
      hugPkg
    ]
    ++ commands;

    systemd.user.services = lib.mkIf (cfg.screentimeHours != null) {
      soft-screentime = {
        Unit.Description = "gentle screen-time nudge";
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe softSet.screentime;
          Environment = [ "SOFT_SCREENTIME_HOURS=${toString cfg.screentimeHours}" ];
        };
      };
    };

    systemd.user.timers = lib.mkIf (cfg.screentimeHours != null) {
      soft-screentime = {
        Unit.Description = "gentle screen-time nudge";
        Timer = {
          # first check an hour in, then hourly. the script itself decides
          # whether enough of the session has passed to say anything.
          OnBootSec = "1h";
          OnUnitActiveSec = "1h";
          Persistent = false;
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
  };
}
