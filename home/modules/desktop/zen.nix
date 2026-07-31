# Zen prefs that live in the profile's user.js (read at every startup, so they
# survive Zen rewriting prefs.js; a restart applies them).
#
# this module is the ONE writer of that file. rice.zenTabgrouper needs a pref of
# its own, so it contributes the line from here instead of writing user.js
# itself: two home.file entries on one path collide.
#
# rice.zen.frameRateCap caps the render rate. on a ProMotion panel Zen renders
# at 120Hz by default, which doubles idle GPU/compositor load (fan + battery)
# for no real gain on a browser. capping to 60 is the same trade as the wezterm
# 60fps cap; set it on the laptop, leave coral (desk, on AC) uncapped.
#
# rice.zen.transparency sheers the CHROME and leaves the page alone: zen-theme.css
# gates `#main-window { background: transparent }` on zen.widget.linux.transparency,
# while browser[type="content"] keeps painting the site's own background. a niri
# window rule cannot do this, its opacity is whole-surface and would dim the
# webpage along with the sidebar.
{
  config,
  lib,
  ...
}:
let
  cfg = config.rice.zen;

  prefs =
    lib.optionalString (cfg.frameRateCap != null) ''
      // cap render to ${toString cfg.frameRateCap}fps to hold down idle GPU/compositor
      // load on the ProMotion panel (fan + battery).
      user_pref("layout.frame_rate", ${toString cfg.frameRateCap});
    ''
    + lib.optionalString cfg.transparency.enable ''
      user_pref("zen.widget.linux.transparency", true);
    ''
    + lib.optionalString (cfg.transparency.enable && cfg.transparency.acrylic) ''
      // backdrop-filter on the toolbar/urlbar. upstream ships it off and its own
      // comment warns it is slow; set acrylic = false if the sidebar drags.
      user_pref("zen.theme.acrylic-elements", true);
    ''
    + lib.optionalString config.rice.zenTabgrouper.enable ''
      // re-enables Zen's native tab groups (Zen ships it false) so the tabgrouper
      // extension sorts into the real tab strip, unpinned, instead of drawing its
      // own UI.
      user_pref("browser.tabs.groups.enabled", true);
    '';
in
{
  options.rice.zen = {
    profilePath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "Library/Application Support/zen/Profiles/c6bgtaur.Default (release)";
      description = ''
        home-relative path to this host's Zen profile. Null = touch no profile,
        which drops both the managed user.js and the tabgrouper's sideloaded XPI.
        The id is generated per install, so it belongs in the host layer.
      '';
    };

    frameRateCap = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      example = 60;
      description = ''
        Cap Zen's render rate (layout.frame_rate) to this many fps via the profile
        user.js. Null leaves Zen at its default (display refresh, 120 on ProMotion).
        Needs rice.zen.profilePath.
      '';
    };

    transparency = {
      enable = lib.mkEnableOption "a see-through Zen sidebar/toolbar on Linux (chrome only, the page stays opaque)";

      acrylic = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Also blur what shows through (zen.theme.acrylic-elements). This is what
          makes the sidebar itself translucent; without it the pref above only
          unlocks the opacity slider in Zen's own theme picker. Costs render time.
        '';
      };
    };
  };

  config = lib.mkIf (cfg.profilePath != null && prefs != "") {
    home.file."${cfg.profilePath}/user.js".text = ''
      // managed by rice.zen (home/modules/desktop/zen.nix), edits here are lost.
      ${prefs}'';
  };
}
