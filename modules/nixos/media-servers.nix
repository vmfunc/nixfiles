# self-hosted media servers for the always-on linux box, gated behind rice.* (off
# by default). currently just suwayomi (tachiyomi-compatible manga server). WHY
# tailnet-only: it exposes a web UI; opening it on the LAN/WAN is a needless
# surface, so the firewall hole is punched ONLY on the tailscale0 interface
# (matches the box's tailscale-transport posture). services.*.openFirewall would
# open on every interface, so it stays off and the port is opened by hand on the
# tailnet. deps: services.tailscale (hosts/tuna).
{
  config,
  lib,
  ...
}:
let
  cfg = config.rice.mediaServers;
  suwayomiPort = 4567; # the suwayomi module default
in
{
  options.rice.mediaServers.manga.enable = lib.mkEnableOption "suwayomi manga server (tailnet-only)";

  config = lib.mkIf cfg.manga.enable {
    services.suwayomi-server = {
      enable = true;
      settings.server.port = suwayomiPort;
    };
    networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ suwayomiPort ];
  };
}
