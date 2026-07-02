# Zen perf knobs that live in the profile's user.js (read at every startup, so
# they survive Zen rewriting prefs.js; a restart applies them).
#
# rice.zen.frameRateCap caps the render rate. on a ProMotion panel Zen renders
# at 120Hz by default, which doubles idle GPU/compositor load (fan + battery)
# for no real gain on a browser. capping to 60 is the same trade as the wezterm
# 60fps cap; set it on the laptop, leave coral (desk, on AC) uncapped.
#
# user.js has ONE writer. rice.zenTabgrouper also writes it (its native-groups
# pref) when enabled, so the assertion below refuses the both-on case rather
# than letting home-manager fail with an opaque file-collision. reconcile by
# folding the tabgrouper pref in here if you ever need both on one host.
{
  config,
  lib,
  ...
}:
let
  cfg = config.rice.zen;
  profilePath = config.rice.zenTabgrouper.profilePath;
  active = cfg.frameRateCap != null && profilePath != null;
in
{
  options.rice.zen.frameRateCap = lib.mkOption {
    type = lib.types.nullOr lib.types.ints.positive;
    default = null;
    example = 60;
    description = ''
      Cap Zen's render rate (layout.frame_rate) to this many fps via the profile
      user.js. Null leaves Zen at its default (display refresh, 120 on ProMotion).
      Requires rice.zenTabgrouper.profilePath to point at the target profile.
    '';
  };

  config = lib.mkIf active {
    assertions = [
      {
        assertion = !config.rice.zenTabgrouper.enable;
        message = "rice.zen.frameRateCap and rice.zenTabgrouper both write the profile user.js; enable only one per host (see home/modules/desktop/zen.nix).";
      }
    ];

    home.file."${profilePath}/user.js".text = ''
      // managed by rice.zen: cap render to ${toString cfg.frameRateCap}fps to hold down
      // idle GPU/compositor load on the ProMotion panel (fan + battery).
      user_pref("layout.frame_rate", ${toString cfg.frameRateCap});
    '';
  };
}
