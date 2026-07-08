{ ... }:
{
  imports = [
    ../modules/cli/restic-linux.nix
    ../modules/desktop/niri.nix
    ../modules/desktop/fuzzel.nix
    ../modules/desktop/mako.nix
    ../modules/desktop/swaylock.nix
    ../modules/desktop/swayosd.nix
    ../modules/desktop/waybar.nix
    ../modules/desktop/qt.nix
    ../modules/desktop/zen-tabgrouper.nix
  ];

  # Claude sorts open Zen tabs into named groups live (cross-platform: the host
  # manifest lands in ~/.mozilla/native-messaging-hosts on Linux). Permanent
  # install needs a signed XPI; until then develop with `zen-tabgrouper-dev`.
  rice.zenTabgrouper.enable = true;
}
