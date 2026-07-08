# tuna home entrypoint: the always-on Framework Desktop (x86_64-linux), niri wayland
# desktop on the "blood" Lain rice. mirrors coral (the always-on darwin desk box) but
# on the linux desktop profile. per-machine HOME deviations only; the shared spine is
# core.nix + profiles/base.nix, the desktop rice is profiles/desktop-linux.nix (niri +
# waybar), the toolkit is profiles/security.nix.
{ ... }:
{
  imports = [
    ./core.nix
    ./profiles/base.nix
    ./profiles/desktop-linux.nix
    # security.nix = the pentest/recon toolkit profile for this host.
    ./profiles/security.nix
    # mail + irc TUIs (macs scope these in desktop-darwin; tuna wants them too).
    # they decrypt their creds from the sops email/irc secrets, which tuna can now
    # read (its age key is a recipient).
    ./modules/cli/aerc.nix
    ./modules/cli/senpai.nix
  ];

  # TODO(deploy): the easystore mount point on tuna is not known yet. keep restic OFF
  # until the drive lands, then set rice.backup.repository/passwordFile and flip this on
  # (see coral.nix / restic-linux.nix for the shape). off here means restic-linux is a
  # clean no-op, so eval stays green with no repository pinned.
  rice.backup.enable = false;
}
