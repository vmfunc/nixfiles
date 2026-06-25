# sets the macOS desktop picture to the reproducible, nix-generated Serial
# Experiments Lain wallpaper (poles + cable tangle over a warm-black field),
# regenerated per palette variant from theme.palette. the generator lives in
# wallpaper-gen.nix; there is NO nix-darwin option for the desktop picture, so
# we drive it by hand via osascript on every activation (idempotent).
{
  pkgs,
  lib,
  theme,
  ...
}:
let
  wallpaper = import ./wallpaper-gen.nix { inherit pkgs lib theme; };
in
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  home.activation.setWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run /usr/bin/osascript -e 'tell application "System Events" to tell every desktop to set picture to "${wallpaper}"' || true
  '';
}
