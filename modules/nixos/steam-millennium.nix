# "old steam" via Millennium, gated behind rice.steamOld.enable (default OFF).
# WHY a hand-rolled gate instead of importing nixos-millennium's own nixosModule:
# that module applies unconditionally on import AND auto-adds a third-party cachix
# substituter as a machine-wide trust root. on a security researcher's box we do
# NOT silently pull in a third-party binary cache, and we do NOT want steam made
# fragile by default, so this module gates everything behind an opt-in and builds
# millennium-steam FROM SOURCE (no cachix). deps: inputs.nixos-millennium (flake),
# programs.steam from modules/nixos/gaming.nix. tuna-only in practice (nixos).
#
# turn it on: set `rice.steamOld.enable = true` on the host, `just switch` (this
# builds the millennium-loader + steam-fhs wrap locally, a real one-time compile),
# then launch steam and pick a retro skin (e.g. "Classic Steam Library") from the
# Millennium theme store in Steam > settings. revert: flip back to false, steam
# runs unmodified again. see docs/gaming.md.
#
# to skip the local build and pull prebuilt instead, add nixos-millennium's cachix
# by hand (nix.settings.substituters + trusted-public-keys) AFTER deciding you
# trust it; deliberately left out here.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.rice.steamOld;
in
{
  options.rice.steamOld.enable = lib.mkEnableOption "millennium-wrapped steam for the old-client skin (opt-in, builds from source)";

  config = lib.mkIf cfg.enable {
    # the overlay brings pkgs.millennium-steam (steam-fhs with the loader
    # preloaded) + pkgs.millenniumThemes / millenniumPlugins into scope.
    nixpkgs.overlays = [ inputs.nixos-millennium.overlays.default ];

    # swap the steam package for the millennium-loader build. gaming.nix owns
    # programs.steam.enable + the rest; this only replaces the package, so plain
    # `programs.steam.enable = true` now boots through Millennium.
    programs.steam.package = pkgs.millennium-steam;
  };
}
