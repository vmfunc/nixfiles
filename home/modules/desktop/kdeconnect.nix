# kdeconnect session half: kdeconnectd as a user service (pairing, mousepad
# remote input, clipboard, file transfer) + the indicator for the waybar tray.
# the system half (firewall, remote-input portal bridge for niri) is
# modules/nixos/kdeconnect.nix, switched per host via rice.kdeconnect. the
# package is pinned to the same one the portal backend's caller allowlist is
# patched against (pkgs/wayland-kdeconnect-fix), so keep them in lockstep.
{ pkgs, ... }:
{
  services.kdeconnect = {
    enable = true;
    package = pkgs.kdePackages.kdeconnect-kde;
    indicator = true;
  };
}
