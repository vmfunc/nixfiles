{ ... }:
{
  imports = [
    ../modules/cli/restic-linux.nix
    # japanese media pipeline: streamlink (live) + yt-dlp (VOD) funnel into the
    # hand-tuned mpv. see modules/nixos/apps.nix for the GUI half (hypnotix etc).
    ../modules/cli/streamlink.nix
    ../modules/cli/yt-dlp.nix
    ../modules/desktop/mpv.nix
    ../modules/desktop/niri.nix
    ../modules/desktop/fuzzel.nix
    ../modules/desktop/mako.nix
    ../modules/desktop/swaylock.nix
    ../modules/desktop/swayosd.nix
    ../modules/desktop/waybar.nix
    ../modules/desktop/qt.nix
    ../modules/desktop/zen-tabgrouper.nix
    ../modules/desktop/nowplaying-rpc-linux.nix
    ../modules/desktop/printing.nix
  ];

  # Claude sorts open Zen tabs into named groups live (cross-platform: the host
  # manifest lands in ~/.mozilla/native-messaging-hosts on Linux). Permanent
  # install needs a signed XPI; until then develop with `zen-tabgrouper-dev`.
  rice.zenTabgrouper.enable = true;
}
