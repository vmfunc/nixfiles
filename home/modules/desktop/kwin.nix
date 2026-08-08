# kwin tuning for the plasma tablet session (rice.tablet.plasmaSession): the
# rice's sheer, applied to apps that cannot do it themselves.
#
# konsole gets TWO layers on purpose: its colorscheme alpha
# (terminal/konsole.nix) fades only the cell background, which alone left the
# tab bar and titlebar solid next to dolphin's sheer. the rule below fades the
# whole window so the chrome matches; stacked, the background lands sheerer
# than the glyphs, which keeps the text readable where a kwin rule alone
# would not. everything else (electron apps like vesktop, the kde apps) has
# no opacity knob of its own, so kwin forces window opacity per wmclass.
#
# kwinrulesrc is plasma-managed: kwin rewrites it at runtime (and the
# systemsettings GUI edits it), so a home.file symlink would be clobbered on
# first run and then backup-churn every switch, exactly like konsolerc. hence
# kwriteconfig6 in an activation step, writing only our own rule groups and
# leaving hand-made rules alone. plasma-manager's window-rules would be the
# typed alternative, but it is all-or-nothing and would drop those hand rules.
#
# cross-file deps: modules/nixos/tablet.nix owns the plasma session this exists
# for; terminal/konsole.nix owns the terminal's own transparency;
# desktop/plasma.nix owns kwinrc (the blur pin lived here until 2026-08-07),
# this module owns kwinrulesrc, one tool per file.
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
        # the electron chat apps (modules/nixos/apps.nix): none has an opacity
        # setting of its own. keys are substrings against kwin's lowercased
        # resource class, so "signal" and "element" match their own windows
        # only.
        { wmclass = "vesktop"; }
        { wmclass = "signal"; }
        { wmclass = "element"; }
        # the kde apps that are mostly chrome over content, where sheer reads as
        # rice rather than as an unreadable wall of translucent text.
        { wmclass = "dolphin"; }
        { wmclass = "ark"; }
        { wmclass = "gwenview"; }
        { wmclass = "systemsettings"; }
        { wmclass = "plasma-systemmonitor"; }
        # kate is text over glass by owner choice (2026-08-07): 92/85 keeps the
        # buffer readable and the editor stops being the one solid pane.
        { wmclass = "kate"; }
        # konsole: layered on top of its own per-cell alpha
        # (terminal/konsole.nix), which sheers the cells but leaves the tab
        # bar / titlebar solid. this rule fades the chrome to match the other
        # kde apps; the glyphs only drop to the values here, the background
        # multiplies both layers.
        { wmclass = "konsole"; }
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

      # apply now instead of at next login. kwin is not running during a switch
      # from a tty or under niri, so a failure here is expected and not an error.
      run ${pkgs.kdePackages.qttools}/bin/qdbus org.kde.KWin /KWin reconfigure \
        2>/dev/null || true
    '';
  };
}
