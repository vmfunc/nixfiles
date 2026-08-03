# reading role for the touch boxes (rice.reading.enable, default off; minnow).
# the shared apps layer (apps.nix) already ships foliate/calibre/komikku/mcomix/
# zathura fleet-wide; this adds the touch-first readers a convertible earns:
# koreader (pdf/epub/cbz, an e-reader UI built for fingers, swipe-to-turn),
# sioyek (keyboard-mode paper reading for laptop posture) and newsflash (rss /
# read-later; it syncs against a miniflux instance natively once one lands on
# an always-on box). manga server side needs nothing new: rice.mediaServers.manga
# (suwayomi, tuna) is already tailnet-reachable and komikku/koreader read from it.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.reading;
in
{
  options.rice.reading.enable = lib.mkEnableOption "touch-first reading stack (koreader/sioyek/newsflash)";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      koreader
      sioyek
      newsflash
    ];
  };
}
