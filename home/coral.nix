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
  ];

  # no EASYSTORE drive lives in the office, so restic has nowhere to write here;
  # restic stays the backup layer on otter/cuttlefish only. desktop-darwin.nix
  # turns backup on by default, so force it back off for this host.
  rice.backup.enable = lib.mkForce false;

  # the AFK external-display dashboard. cross-file dependency: this option is
  # defined in ./modules/desktop/dashboard.nix (rice.dashboard.enable). if that
  # module renames the option, update this line to match.
  # flood-proof watcher (single-instance + 90s cooldown) launching an ISOLATED
  # wezterm-gui (own WEZTERM_UNIX_SOCKET) so the kiosk renders + closes cleanly
  # instead of folding into the running wezterm. panes are macos-safe.
  # Chromium-kiosk web dashboard (OS-foregrounded via `open`, fullscreen via --kiosk).
  # appears after 5 min away from the keyboard, vanishes the moment you touch input.
  rice.dashboard.enable = true;
  rice.dashboard.idleSeconds = 300;

  # pentest/recon scratch dir. this is a TOOLKIT + a scratch directory ONLY: no
  # autonomous always-on scanning daemon is shipped here, on purpose, for opsec
  # and authorization reasons (every scan stays a deliberate, attributable act).
  home.activation.reconDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "${config.home.homeDirectory}/recon"
  '';
}
