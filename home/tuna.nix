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
    # signal TUI (linked device). tuna-scoped for now; add to desktop-darwin if
    # the macs ever want it (gurk-rs builds on darwin too).
    ./modules/cli/gurk.nix
    # riced doom emacs (built from source), tuna's default editor. TUNA-ONLY: the
    # module's IFD would break the macs' cross-platform drvPath eval in CI. it sets
    # EDITOR/VISUAL to a terminal `e` wrapper via mkForce, overriding the nvim default.
    ./modules/editor/emacs
    # game shader layer + perf overlay config (system halves live in
    # modules/nixos/gaming.nix). tuna-scoped, not in desktop-linux: they track
    # the rice.gaming role, not the rice. both are opt-in per game launch.
    ./modules/desktop/vkbasalt.nix
    ./modules/desktop/mangohud.nix
    # Binary Ninja "Wired Blood" theme + MCP plugin (linux paths). the licensed BN
    # linux build is a manual install (TODO(deploy) in the module); the binja-mcp
    # bridge comes from re.nix. the macs get this same module via desktop-darwin.
    ./modules/desktop/binary-ninja.nix
  ];

  # TODO(deploy): the easystore mount point on tuna is not known yet. keep restic OFF
  # until the drive lands, then set rice.backup.repository/passwordFile and flip this on
  # (see coral.nix / restic-linux.nix for the shape). off here means restic-linux is a
  # clean no-op, so eval stays green with no repository pinned.
  rice.backup.enable = false;
}
