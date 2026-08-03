# couch mode (rice.couch.*, default off; minnow): the "this laptop is now an
# appliance" surface for convertible/couch posture. v1 is deliberately small:
# `couch` throws a fullscreen big-icon touch launcher over the session
# (nwg-drawer on the layer-shell overlay, fed by the normal .desktop entries),
# sized for fingers, dismissed by launching or tapping outside. media strip and
# a jellyfin tile can graft on later once a media server exists to point at.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.couch;

  couch = pkgs.writeShellScriptBin "couch" ''
    # -ovl paints the whole output so it reads as an appliance, not a popup.
    exec ${pkgs.nwg-drawer}/bin/nwg-drawer \
      -c ${toString cfg.columns} -is ${toString cfg.iconSize} -spacing 24 -ovl
  '';
in
{
  options.rice.couch = {
    enable = lib.mkEnableOption "couch mode (fullscreen touch launcher)";
    columns = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "icon grid columns; 4 fits a 12-inch panel at 1.25 scale";
    };
    iconSize = lib.mkOption {
      type = lib.types.int;
      default = 128;
      description = "icon size in px; finger-sized, not cursor-sized";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.nwg-drawer
      couch
    ];
  };
}
