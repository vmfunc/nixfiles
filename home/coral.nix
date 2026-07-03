{ config, lib, ... }:
{
  imports = [
    ./core.nix
    ./profiles/base.nix
    # coral runs in clamshell with an external display in the office, so it is a
    # real desktop, not headless: keep the full darwin desktop rice.
    ./profiles/desktop-darwin.nix
    # security.nix = the pentest/recon toolkit profile for this host.
    ./profiles/security.nix
    # dashboard.nix = the AFK idle external-display dashboard (written separately).
    ./modules/desktop/dashboard.nix
    # datamosh.nix = the Lain signal-loss idle field (rice.datamosh.enable, off by default).
    ./modules/desktop/datamosh.nix
  ];

  # no EASYSTORE drive lives in the office, so restic has nowhere to write here;
  # restic stays the backup layer on otter only. desktop-darwin.nix turns backup
  # on by default, so turn it back off for this host.
  rice.backup.enable = false;

  # AFK dashboard off (azzie found it annoying). the module stays imported so it
  # can come back; implementation + the rice.dashboard option live in
  # ./modules/desktop/dashboard.nix.
  rice.dashboard.enable = false;

  # pentest/recon scratch dir. this is a TOOLKIT + a scratch directory ONLY: no
  # autonomous always-on scanning daemon is shipped here, on purpose, for opsec
  # and authorization reasons (every scan stays a deliberate, attributable act).
  home.activation.reconDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "${config.home.homeDirectory}/recon"
  '';
}
