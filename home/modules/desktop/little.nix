# rice.little: the `little` / `big` pair, plus `hug`. see pkgs/little/package.nix
# for what the flip actually touches (all runtime knobs, no rebuild).
#
# callPackage against the repo paths rather than pkgs.*: the custom-pkgs overlay
# is darwin-gated, and `little` is wayland/niri-only anyway.
# cross-file deps: theme.nix owns the accent `hug` prints in; niri.nix owns the
# compositor whose output scale gets flipped.
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

  # one word out, one word back. `little off` works too, but nobody in little
  # space wants to remember a subcommand.
  big = pkgs.writeShellApplication {
    name = "big";
    text = "exec ${lib.getExe littlePkg} off";
  };
in
{
  options.rice.little = {
    enable = lib.mkEnableOption "the `little` / `big` mode flip and the `hug` command";

    scale = lib.mkOption {
      type = lib.types.numbers.between 1.0 3.0;
      default = 1.6;
      description = "niri output scale while little. Bigger text, fewer things on screen.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      littlePkg
      big
      hugPkg
    ];
  };
}
