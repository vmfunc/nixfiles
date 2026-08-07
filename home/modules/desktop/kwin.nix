# kwin tuning for the plasma tablet session (rice.tablet.plasmaSession): the
# rice's sheer, applied to apps that cannot do it themselves.
#
# TWO different mechanisms on purpose:
#   - konsole does its OWN transparency, in terminal/konsole.nix, via the
#     colorscheme's Opacity. that is per-CELL background alpha, so the text
#     stays fully opaque and readable. a kwin rule here would instead fade the
#     whole window including the glyphs, which looks bad on a terminal, so
#     konsole is deliberately NOT in the app list below.
#   - everything else (electron apps like vesktop, the kde apps) has no opacity
#     knob of its own, so kwin forces window opacity per wmclass.
#
# kwinrulesrc and kwinrc are BOTH plasma-managed: kwin rewrites them at runtime
# (and the systemsettings GUI edits them), so a home.file symlink would be
# clobbered on first run and then backup-churn every switch, exactly like
# konsolerc. hence kwriteconfig6 in an activation step, writing only our own
# rule groups and leaving hand-made rules alone.
#
# cross-file deps: modules/nixos/tablet.nix owns the plasma session this exists
# for; terminal/konsole.nix owns the terminal's own transparency.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.kwin;

  # stable group names so re-running activation overwrites our groups instead of
  # growing a new one each switch. kwin writes uuid-shaped names, so match that
  # shape (the last field is the index) rather than inventing a format.
  groupFor = i: "{5b1cea00-0000-4000-8000-${lib.fixedWidthString 12 "0" (toString i)}}";

  ruleList = lib.imap0 (i: app: {
    group = groupFor i;
    inherit (app) wmclass active inactive;
  }) cfg.transparency.apps;

  writeRule =
    r:
    let
      set = key: val: ''
        run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kwinrulesrc \
          --group ${lib.escapeShellArg r.group} --key ${key} ${lib.escapeShellArg (toString val)}
      '';
    in
    lib.concatStrings [
      (set "Description" "rice sheer: ${r.wmclass}")
      (set "wmclass" r.wmclass)
      (set "wmclasscomplete" "false")
      # 2 = substring match, so a class of "vesktop" still catches
      # "vesktop.Vesktop" without pinning the exact string.
      (set "wmclassmatch" 2)
      (set "opacityactive" r.active)
      # 2 = Force, the only rule type that wins against the app's own choice.
      (set "opacityactiverule" 2)
      (set "opacityinactive" r.inactive)
      (set "opacityinactiverule" 2)
    ];
in
{
  options.rice.kwin = {
    enable = lib.mkEnableOption "kwin tuning for the plasma session (per-app sheer + blur)";

    transparency.apps = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            wmclass = lib.mkOption {
              type = lib.types.str;
              description = "window class to match (substring, case-sensitive)";
            };
            active = lib.mkOption {
              type = lib.types.ints.between 10 100;
              default = 92;
              description = "opacity percent while focused";
            };
            inactive = lib.mkOption {
              type = lib.types.ints.between 10 100;
              default = 85;
              description = "opacity percent while unfocused";
            };
          };
        }
      );
      default = [
        # vesktop: the discord client (modules/nixos/apps.nix). electron, so no
        # opacity setting of its own.
        { wmclass = "vesktop"; }
        # the kde apps that are mostly chrome over content, where sheer reads as
        # rice rather than as an unreadable wall of translucent text.
        { wmclass = "dolphin"; }
        { wmclass = "ark"; }
        { wmclass = "gwenview"; }
        { wmclass = "systemsettings"; }
        { wmclass = "plasma-systemmonitor"; }
      ];
      description = "per-app window opacity forced through kwin rules";
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation.kwinSheer = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${lib.concatMapStrings writeRule ruleList}

      # keep any rule she made by hand: read the current list, drop OUR group
      # names, then put ours back in front. without this a hand-made rule would
      # be silently dropped from the index every switch (the group would survive
      # in the file but stop being applied, which is the confusing failure).
      ours="${lib.concatMapStringsSep "," (r: r.group) ruleList}"
      existing="$(${pkgs.kdePackages.kconfig}/bin/kreadconfig6 --file kwinrulesrc \
        --group General --key rules 2>/dev/null || true)"
      keep=""
      keptCount=0
      for r in ''${existing//,/ }; do
        case ",$ours," in
          *",$r,"*) ;;
          *)
            keep="''${keep:+$keep,}$r"
            keptCount=$((keptCount + 1))
            ;;
        esac
      done
      run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kwinrulesrc \
        --group General --key rules "$ours''${keep:+,$keep}"
      run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kwinrulesrc \
        --group General --key count "$(( ${toString (builtins.length ruleList)} + keptCount ))"

      # blur is what makes the sheer read as glass instead of as a smudge. it is
      # on by default in plasma, but pin it so a stray toggle in systemsettings
      # does not quietly flatten the whole rice.
      run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kwinrc \
        --group Plugins --key blurEnabled true

      # apply now instead of at next login. kwin is not running during a switch
      # from a tty or under niri, so a failure here is expected and not an error.
      run ${pkgs.kdePackages.qttools}/bin/qdbus org.kde.KWin /KWin reconfigure \
        2>/dev/null || true
    '';
  };
}
