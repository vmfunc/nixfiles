# nextcloud on the linux desktops: the files sync client as a user service plus
# the talk desktop app. files is the only piece that needs its own daemon; the
# calendar/contacts side is NOT here because it already exists: programs.kde-pim
# (modules/nixos/kde-apps.nix) ships kdepim-runtime, whose DAV groupware
# resource syncs nextcloud calendars/contacts straight into korganizer, merkuro
# and kontact.
#
# deliberately NO session fence on the unit: unlike waybar/swayosd this daemon
# belongs in BOTH sessions (waybar tray under niri, plasma systray in tablet
# posture), so bare graphical-session.target is correct.
#
# TODO(deploy): account setup is manual and stays out of nix: log in once in
# the sync client (webflow) and once in kontact/merkuro (settings -> add DAV
# groupware resource, same server url). tokens land in the wallet, not the tree.
{ pkgs, ... }:
{
  services.nextcloud-client = {
    enable = true;
    # tray-only start; the main window is one tray click away when wanted.
    startInBackground = true;
  };

  home.packages = [ pkgs.nextcloud-talk-desktop ];
}
