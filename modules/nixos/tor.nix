# tor for the linux boxes (rice.tor.*), default OFF, switched on per host.
# client-only: services.tor.client wires SocksPort 127.0.0.1:9050 with the
# upstream safe-client defaults, and torsocks rides along automatically
# (services.tor.torsocks defaults on when client.enable is set). deliberately
# NO relay/exit config: these are personal research boxes on residential /
# travel connections, not infrastructure. tor-browser keeps its own bundled
# tor + circuits, which is the correct isolation for browsing; the system
# daemon is for tooling (torsocks curl, proxychains, onion service recon).
{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  cfg = config.rice.tor;
in
{
  options.rice.tor.enable = lib.mkEnableOption "tor client daemon + tor browser";

  config = lib.mkIf cfg.enable {
    services.tor = {
      enable = true;
      client.enable = true;
      # unix control socket at /run/tor/control (group tor) so nyx can attach
      # without a password-auth ControlPort listening on tcp.
      controlSocket.enable = true;
    };

    # the control socket is 0660 root:tor; without this nyx dies on EACCES.
    users.users.${username}.extraGroups = [ "tor" ];

    environment.systemPackages = with pkgs; [
      tor-browser
      nyx # daemon status/circuit TUI over the control socket
    ];
  };
}
