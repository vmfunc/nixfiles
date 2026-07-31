# rice.cozy: the `cozy` wind-down command (see pkgs/cozy/package.nix for what it
# actually does to the screen, notifications and sound).
#
# callPackage against the repo path rather than pkgs.cozy: the custom-pkgs
# overlay is darwin-gated, and this one is wayland-only anyway (gammastep,
# makoctl, brightnessctl).
# cross-file deps: mako.nix owns the notification daemon whose mode this flips.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.cozy;
in
{
  options.rice.cozy = {
    enable = lib.mkEnableOption "the `cozy` wind-down command";

    soundUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "https://somafm.com/dronezone130.pls";
      description = ''
        Soundscape stream URL or local file to loop while cozy. Null keeps it
        silent, so the wind-down still works with no network.
      '';
    };

    dimPercent = lib.mkOption {
      type = lib.types.ints.between 1 100;
      default = 35;
      description = "Backlight level while cozy, as a percentage.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.callPackage ../../../pkgs/cozy/package.nix {
        inherit (cfg) soundUrl dimPercent;
      })
    ];
  };
}
