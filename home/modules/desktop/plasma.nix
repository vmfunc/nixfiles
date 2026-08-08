# the plasma tablet session's declarative layer (rice.plasma, minnow):
# plasma-manager for everything static, deliberately thin. the session stays
# plasma-shaped by owner decision (2026-08-07): stock breeze dark, stock fonts,
# stock panel layout and shortcuts; the rice is glass (sheer + blur), physics
# (wobbly windows) and the tv-off close effect, nothing else.
#
# file ownership: this module owns kwinrc (effect toggles + blur knobs) and
# the plasma-manager-managed rc files; desktop/kwin.nix keeps kwinrulesrc (its
# kwriteconfig6 merge preserves hand-made rules, which plasma-manager's
# all-or-nothing window-rules would wipe). do not point both tools at one file.
#
# the panel is NOT declared through programs.plasma.panels: that replaces every
# panel wholesale on first activation. the startup desktop script below instead
# mutates the live panel's two properties (floating + translucent) and leaves
# the rest of its state to plasma, same surgical philosophy as kwin.nix.
#
# cross-file deps: modules/nixos/tablet.nix owns the session; pkgs/
# burn-my-windows-tv ships the close effect this enables; terminal/konsole.nix
# relies on the blur pinned here for its glass.
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.plasma;
in
{
  imports = [ inputs.plasma-manager.homeModules.plasma-manager ];

  options.rice.plasma.enable = lib.mkEnableOption "declarative plasma session config (plasma-manager)";

  config = lib.mkIf cfg.enable {
    programs.plasma = {
      enable = true;

      # breeze dark by choice, not omission: plasma defaults to light breeze,
      # and the sheer stack reads as smoke on a light scheme.
      workspace.colorScheme = "BreezeDark";

      kwin.effects = {
        wobblyWindows.enable = true;
        # kwin's own defaults (blur.kcfg: 15/5), pinned so a stray
        # systemsettings toggle cannot quietly flatten the glass. this replaces
        # the blurEnabled pin kwin.nix used to carry.
        blur = {
          enable = true;
          strength = 15;
          noiseStrength = 5;
        };
      };

      # start clean like niri does; wayland session restore is half-built
      # upstream anyway and the tablet posture never wants yesterday's windows.
      session.sessionRestore.restoreOpenApplicationsOnLogin = "startWithEmptySession";

      configFile = {
        # the tv-off close animation (pkgs/burn-my-windows-tv). js + glsl
        # kpackage, so no kwin abi coupling; the id is upstream's dir name.
        kwinrc.Plugins.kwin6_effect_tvEnabled = true;

        # baloo: filenames only. content indexing would crawl workspace/pentest
        # trees on battery for search depth nothing here needs; filename search
        # in krunner/dolphin survives basic indexing.
        baloofilerc."Basic Settings"."Indexing-Enabled" = true;
        baloofilerc.General."only basic indexing" = true;
      };

      # runAlways: a GUI opacity change would otherwise survive until the next
      # text change of this script instead of the next login.
      startup.desktopScript.panel_sheer = {
        runAlways = true;
        text = ''
          for (const p of panels()) {
            p.floating = true;
            p.opacity = "translucent";
          }
        '';
      };
    };

    home.packages = [ pkgs.burn-my-windows-tv ];
  };
}
