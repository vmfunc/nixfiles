# 3d printing: slicers for the bambu lab printer. orca-slicer is the primary
# (open-source, best bambu profiles + calibration flows); bambu-studio is the
# official app kept alongside for firmware pushes and anything orca lags on.
# LAN-mode discovery (avahi mDNS + bambu's SSDP udp ports) is wired at the system
# layer in hosts/tuna. imported from home/profiles/desktop-linux.nix (linux-only
# by that import; both slicers are linux-only packages anyway).
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    orca-slicer
    # bambu-studio  # re-enabled below once its from-source build lands (uncached)
  ];
}
