{ ... }:
{
  imports = [
    ../modules/cli/restic-linux.nix
    # japanese media pipeline: streamlink (live) + yt-dlp (VOD) funnel into the
    # hand-tuned mpv. see modules/nixos/apps.nix for the GUI half (hypnotix etc).
    ../modules/cli/streamlink.nix
    ../modules/cli/yt-dlp.nix
    ../modules/desktop/mpv.nix
    ../modules/desktop/jptv.nix
    # recording/streaming (pipewire portal capture + vkcapture game capture).
    ../modules/desktop/obs.nix
    ../modules/desktop/niri.nix
    ../modules/desktop/fuzzel.nix
    ../modules/desktop/mako.nix
    ../modules/desktop/swaylock.nix
    ../modules/desktop/swayosd.nix
    ../modules/desktop/waybar
    ../modules/desktop/qt.nix
    ../modules/desktop/cozy.nix
    ../modules/desktop/little.nix
    ../modules/desktop/zen.nix
    ../modules/desktop/zen-tabgrouper.nix
    ../modules/desktop/nowplaying-rpc-linux.nix
    ../modules/desktop/printing.nix
    # kdeconnectd + tray indicator; remote input works because the system layer
    # ships the RemoteDesktop portal bridge (rice.kdeconnect, on for both boxes).
    ../modules/desktop/kdeconnect.nix
  ];

  # Claude sorts open Zen tabs into named groups live (cross-platform: the host
  # manifest lands in ~/.mozilla/native-messaging-hosts on Linux). Permanent
  # install needs a signed XPI; until then develop with `zen-tabgrouper-dev`.
  rice.zenTabgrouper.enable = true;

  # sheer Zen's sidebar and toolbar over the wallpaper, page content untouched.
  # lands only where rice.zen.profilePath is set.
  # TODO(deploy): read tuna's profile id out of ~/.config/zen/profiles.ini and set
  # rice.zen.profilePath in home/tuna.nix, otherwise this is a no-op there.
  rice.zen.transparency.enable = true;

  # `cozy` winds the desk down in one word. soundUrl stays null until azzie picks
  # a stream she actually likes, the rest works without it.
  rice.cozy.enable = true;

  # `little` / `big` flip the compositor scale and warmth; `hug` comes with them.
  rice.little.enable = true;

}
