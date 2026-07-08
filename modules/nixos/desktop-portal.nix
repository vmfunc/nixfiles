# home-manager portals with useGlobalPkgs need the SYSTEM profile to link the
# portal dirs: hm's xdg.portal module asserts environment.pathsToLink covers
# them, because the user profile alone cannot expose portal configs to dbus.
{ ... }:
{
  environment.pathsToLink = [
    "/share/xdg-desktop-portal"
    "/share/applications"
  ];
}
