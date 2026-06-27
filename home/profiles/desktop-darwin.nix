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
    ../modules/desktop/live-wire.nix
    ../modules/desktop/auth-flinch.nix
    ../modules/desktop/autoraise.nix
    ../modules/desktop/vesktop.nix
    ../modules/desktop/music-presence.nix
    ../modules/cli/scrobble.nix
    ../modules/desktop/zen-tabgrouper.nix
    ../modules/cli/restic-darwin.nix
    ../modules/cli/reminders.nix
    ../modules/terminal/ghostty.nix

    # mail + irc + RE, macs only (per azzie). aerc/senpai are TUIs but scoped here
    # (not base.nix) so they land on otter + coral, not cuttlefish. binary-ninja.nix
    # is the BN theme only; the cask is in modules/darwin/homebrew.nix.
    ../modules/cli/aerc.nix
    ../modules/cli/senpai.nix
    ../modules/desktop/binary-ninja.nix
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

    # the Wired terminal cockpit + the // WIRED // notification helper
    navi
    wired-notify

    # claude-side stdio bridge to the Binary Ninja MCP plugin (server half wired in
    # home/modules/desktop/binary-ninja.nix). darwin-only, so it sits here not in the
    # cross-platform security.nix. register once: `claude mcp add binja -- binja-mcp`.
    binja-mcp

    signal-desktop
    telegram-desktop
    vesktop
  ];
}
