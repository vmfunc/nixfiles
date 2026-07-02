# sets the macOS desktop picture to the vendored Serial Experiments Lain
# wallpaper (wallpaper.jpg here). vendored, not theme-generated, so every host
# shows the same image; on coral lumen renders above it, on otter (lumen off)
# this is what shows. the linux side (cuttlefish/hyprland) hands the SAME file
# to swww, see home/modules/desktop/hyprland.nix. there is NO nix-darwin option
# for the desktop picture, so drive it by hand via osascript each activation.
{
  pkgs,
  lib,
  ...
}:
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  home.activation.setWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run /usr/bin/osascript -e 'tell application "System Events" to tell every desktop to set picture to "${./wallpaper.jpg}"' || true
  '';
}
