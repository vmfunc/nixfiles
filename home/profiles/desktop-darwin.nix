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
    ../modules/desktop/lumen.nix
    ../modules/desktop/wired-sound.nix
    ../modules/desktop/autoraise.nix
    ../modules/desktop/vesktop.nix
    ../modules/desktop/music-presence.nix
    ../modules/cli/scrobble.nix
    ../modules/desktop/zen-tabgrouper.nix
    ../modules/cli/restic-darwin.nix
    ../modules/cli/reminders.nix
    ../modules/terminal/ghostty.nix
  ];

  # Claude sorts open Zen tabs into named groups live; collapse/close a group to
  # free RAM and reopen it later. Permanent install needs a signed XPI (set
  # rice.zenTabgrouper.signedXpi); until then develop with `zen-tabgrouper-dev`.
  rice.zenTabgrouper.enable = true;

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
