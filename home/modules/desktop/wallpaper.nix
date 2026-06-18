{
  pkgs,
  lib,
  inputs,
  theme,
  ...
}:
let
  wallpaper = "${inputs.wallpapers}/${theme.wallpaperFile}";
in
lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
  home.activation.setWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run /usr/bin/osascript -e 'tell application "System Events" to tell every desktop to set picture to "${wallpaper}"' || true
  '';
}
