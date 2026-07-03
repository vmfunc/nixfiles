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
    ../modules/desktop/nowplaying-rpc.nix
    ../modules/cli/scrobble.nix
    ../modules/desktop/zen.nix
    ../modules/desktop/zen-tabgrouper.nix
    ../modules/cli/restic-darwin.nix
    ../modules/cli/reminders.nix
    ../modules/terminal/ghostty.nix

    # mail + irc + RE, macs only (per azzie). aerc/senpai are TUIs but scoped here
    # (not base.nix) so they land on otter + coral only. binary-ninja.nix
    # is the BN theme only; the cask is in modules/darwin/homebrew.nix.
    ../modules/cli/aerc.nix
    ../modules/cli/senpai.nix
    ../modules/desktop/binary-ninja.nix

    # defines rice.homeMounts (SMB auto-mount); off here, enabled per-roaming-host.
    ../modules/desktop/home-mounts.nix
  ];

  # tabgrouper off on the macs: the dev build's background page repaints the GPU even
  # with no tabs open (fan/heat). re-enable when there's a signed XPI to test against
  # (rice.zenTabgrouper.signedXpi), or develop ad-hoc with `zen-tabgrouper-dev`.
  rice.zenTabgrouper.enable = false;

  rice.backup = {
    # mkDefault so a host without the drive (coral) can turn it off with a plain value
    enable = lib.mkDefault true;
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
    # vesktop comes from programs.vesktop (home/modules/desktop/vesktop.nix), not here
  ];

  # Now Playing -> Discord rich presence (covers browser SoundCloud, Spotify, ...;
  # Apple Music is left to music-presence by default, see the module). the client
  # id is a PLACEHOLDER: Music Presence's public shared "Music" application, so the
  # status reads "Listening to Music". swap in a personal-named app id once a
  # Discord dev-portal login is possible again (browser 2FA currently blocks it).
  rice.nowPlayingRpc = {
    enable = true;
    clientId = "1205619376275980288";
    # host non-catalog covers (SoundCloud uploads) on an ephemeral file host so
    # they actually render in Discord. azzie opted into this tradeoff knowingly;
    # see the privacy note in home/modules/desktop/nowplaying-rpc.nix.
    uploadArtwork = true;
  };
}
