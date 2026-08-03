# minnow home entrypoint: the framework 12 convertible (x86_64-linux), same
# lain rice as guppy/tuna plus the touch layer: tablet-mode session glue, couch
# mode, and the ink-ocr writer for the vault. per-machine HOME deviations only;
# shared spine is core.nix + profiles/base.nix, desktop rice is
# profiles/desktop-linux.nix (which also carries the note system), toolkit is
# profiles/security.nix.
{ ... }:
{
  imports = [
    ./core.nix
    ./profiles/base.nix
    ./profiles/desktop-linux.nix
    # pentest/recon toolkit: this machine travels too.
    ./profiles/security.nix
    # mail + irc TUIs; creds come from the sops email/irc secrets.
    # TODO(deploy): these decrypt only after the migration rekey adds minnow's
    # age key to the secrets recipients.
    ./modules/cli/aerc.nix
    ./modules/cli/senpai.nix
    # signal TUI (linked device), same as tuna/guppy.
    ./modules/cli/gurk.nix
    # riced doom emacs, the default editor (sets EDITOR/VISUAL via mkForce).
    ./modules/editor/emacs
    # binary ninja theme + MCP plugin; the licensed BN build itself is a manual
    # install, same TODO(deploy) as the other boxes.
    ./modules/desktop/binary-ninja.nix
    # standing care nudges (water/food/stretch).
    ./modules/cli/care.nix
  ];

  # the travel boxes are the ones that forget to eat; same care config as guppy.
  rice.care.enable = true;
  rice.care.hourlyChime = true;
  rice.bar.meds.enable = true;
  rice.bar.style = "islands";
  rice.look = "soft";
  rice.bar.water.enable = true;
  rice.care.medsTimes = [
    "09:00"
    "13:00"
    "22:00"
  ];

  # no restic target from the road yet, same open question as guppy.
  rice.backup.enable = false;

  # laptop, so the bar carries the BAT charge cell.
  rice.bar.battery.enable = true;

  # the touch layer (session half; the system half is rice.tablet in
  # hosts/minnow): accelerometer-follow rotation + the `osk` keyboard toggle,
  # and `couch` for appliance posture.
  rice.tablet.enable = true;
  rice.couch.enable = true;
  # ink -> searchable sidecars. enabled ONLY here across the fleet: one writer
  # into the synced vault means no two boxes race sidecars through obsidian sync.
  rice.inkOcr.enable = true;

  rice.little.comfortPeople = [
    "cyb"
    "asriel"
    "val"
    "ami"
    "naomi"
    "vio"
  ];

  # TODO(deploy): after first boot, read minnow's zen profile id out of
  # ~/.config/zen/profiles.ini and set rice.zen.profilePath here, otherwise the
  # zen transparency layer is a no-op on this box.
}
