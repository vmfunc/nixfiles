# self-hosted media servers for the always-on linux box, each gated behind its own
# rice.* option (default off). jellyfin = video/live-tv DVR, suwayomi = manga
# server (tachiyomi-compatible). WHY tailnet-only: these expose web UIs; opening
# them on the LAN/WAN is a needless surface, so the firewall holes are punched
# ONLY on the tailscale0 interface (matches the box's tailscale-transport posture).
# services.*.openFirewall would open on every interface, so it stays off and the
# ports are opened by hand on the tailnet. deps: services.tailscale (hosts/tuna).
{
  config,
  lib,
  ...
}:
let
  cfg = config.rice.mediaServers;
  # jellyfin http (8096); suwayomi web (4567, the module default).
  jellyfinPort = 8096;
  suwayomiPort = 4567;
in
{
  options.rice.mediaServers = {
    jellyfin.enable = lib.mkEnableOption "jellyfin video server (tailnet-only)";
    manga.enable = lib.mkEnableOption "suwayomi manga server (tailnet-only)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.jellyfin.enable {
      services.jellyfin.enable = true;
      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ jellyfinPort ];
    })
    (lib.mkIf cfg.manga.enable {
      services.suwayomi-server = {
        enable = true;
        settings.server.port = suwayomiPort;
      };
      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ suwayomiPort ];
    })
  ];
}
