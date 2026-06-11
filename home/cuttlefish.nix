{ config, ... }:
{
  imports = [
    ./core.nix
    ./profiles/base.nix
    ./profiles/desktop-linux.nix
    ./profiles/security.nix
  ];

  rice.backup = {
    enable = true;
    # adjust once the drive's real mount point is known
    repository = "/run/media/quaver/EASYSTORE/restic-repo";
    passwordFile = config.sops.secrets."restic-password".path;
  };
}
