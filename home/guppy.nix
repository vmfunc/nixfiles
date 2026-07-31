# guppy home entrypoint: the travel laptop (x86_64-linux), same niri/"blood"
# lain rice as tuna. per-machine HOME deviations only; shared spine is core.nix +
# profiles/base.nix, desktop rice is profiles/desktop-linux.nix, toolkit is
# profiles/security.nix. mirrors tuna minus the desk-box-only bits (gaming
# overlays, emacs-from-source is kept: linux host, so no cross-platform CI IFD
# concern).
{ ... }:
{
  imports = [
    ./core.nix
    ./profiles/base.nix
    ./profiles/desktop-linux.nix
    # pentest/recon toolkit: this machine travels to the places it's needed.
    ./profiles/security.nix
    # mail + irc TUIs; creds come from the sops email/irc secrets (guppy's age
    # key is a recipient as of the 2026-07-29 rekey).
    ./modules/cli/aerc.nix
    ./modules/cli/senpai.nix
    # signal TUI (linked device), same as tuna.
    ./modules/cli/gurk.nix
    # riced doom emacs, the default editor (sets EDITOR/VISUAL via mkForce).
    ./modules/editor/emacs
    # binary ninja theme + MCP plugin (linux paths); the licensed BN build itself
    # is a manual install, same TODO(deploy) as tuna.
    ./modules/desktop/binary-ninja.nix
    # standing care nudges (water/food/stretch), separate from the `remind` store.
    ./modules/cli/care.nix
  ];

  # the travel laptop is the one that forgets to eat. meds fire Persistent, so a
  # dose missed while the lid was shut still gets asked about on wake.
  rice.care.enable = true;
  rice.care.hourlyChime = true;
  # the heart in the bar fills while a dose is pending; clicking it acks.
  rice.bar.meds.enable = true;
  # the floating-pill redesign. flip back to "console" for the old lain strip,
  # which waybar/console.nix keeps verbatim.
  rice.bar.style = "islands";
  # rounded + clipped corners, a workspace-wide gradient frame, springs, and the
  # matching launcher/notification surfaces. "hairline" is the original wired look.
  rice.look = "soft";
  rice.bar.water.enable = true;
  rice.care.medsTimes = [
    "09:00"
    "13:00"
    "22:00"
  ];

  # no restic target from the road yet; wire a repository + flip on once the
  # backup story for roaming hosts is decided (vps? nas over tailscale?).
  rice.backup.enable = false;

  # laptop, so the shared niri bar carries a BAT charge cell (off on tuna, the
  # battery-less desk box). color/format mirror the mac's sketchybar battery.
  rice.bar.battery.enable = true;

  # guppy's Zen profile id (from ~/.config/zen/profiles.ini), where rice.zen drops
  # user.js. generated at install time, so it differs per machine.
  # names only, no numbers: this repo is a public mirror (see the option's warning).
  rice.little.comfortPeople = [
    "cyb"
    "asriel"
    "val"
    "ami"
    "naomi"
    "vio"
  ];

  rice.zen.profilePath = ".config/zen/w5u2kvyr.Default Profile";
}
