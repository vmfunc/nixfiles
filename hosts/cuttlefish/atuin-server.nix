# self-hosted atuin sync server for every shell in the fleet; clients point at
# cuttlefish over the tailnet (home/modules/shell/atuin.nix). plain http on
# purpose: the port is opened on tailscale0 only, so it is unreachable off the
# tailnet and wireguard already encrypts the path end to end, tls would add
# nothing but cert plumbing. postgres comes from services.atuin's local
# database default; its data dir merges into the modules/nixos/impermanence.nix
# persist list.
{
  config,
  lib,
  ...
}:
let
  # wildcard bind so tailscale0 can reach it; the interface-scoped firewall
  # rule below is the actual access control
  atuinHost = "0.0.0.0";
  atuinPort = 8888;
in
{
  services.atuin = {
    enable = true;
    openRegistration = false;
    host = atuinHost;
    port = atuinPort;
    openFirewall = false; # never on the LAN; only the tailnet rule below opens it
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ atuinPort ];

  # postgres data dir must survive wipe-on-boot; merges into impermanence.nix list
  environment.persistence."/persist" = lib.mkIf config.services.postgresql.enable {
    directories = [
      {
        directory = "/var/lib/postgresql";
        user = "postgres";
        group = "postgres";
        mode = "u=rwx,g=rx,o=";
      }
    ];
  };
}
