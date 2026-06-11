{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../modules/desktop/aerospace.nix
    ../modules/desktop/sketchybar.nix
    ../modules/desktop/wallpaper.nix
    ../modules/desktop/autoraise.nix
    ../modules/cli/restic-darwin.nix
    ../modules/cli/reminders.nix
  ];

  rice.backup = {
    enable = true;
    repository = "/Volumes/EASYSTORE/restic-repo";
    passwordFile = config.sops.secrets."restic-password".path;
    exclude = [ "${config.home.homeDirectory}/workspace/easystore-export" ];
  };

  # screencapture.location points here; macos falls back to hidden Desktop if missing
  home.activation.screenshotsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "${config.home.homeDirectory}/workspace/screenshots"
  '';

  home.packages = with pkgs; [
    raycast
    sketchybar
    sketchybar-app-font

    signal-desktop
    telegram-desktop
    vesktop
  ];
}
