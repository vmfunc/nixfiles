{
  config,
  lib,
  ...
}:
let
  atuinHost = "127.0.0.1";
  atuinPort = 8888;
in
{
  services.atuin = {
    enable = true;
    openRegistration = false;
    host = atuinHost;
    port = atuinPort;
    openFirewall = false;
  };

  services.tailscale = {
    enable = true;
    permitCertUid = "atuin";
  };

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
