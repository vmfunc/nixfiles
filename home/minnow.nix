# minnow home entrypoint: the framework 12 convertible (x86_64-linux), same
# lain rice as guppy/tuna plus the touch layer: tablet-mode session glue, couch
# mode, and the ink-ocr writer for the vault. per-machine HOME deviations only;
# shared spine is core.nix + profiles/base.nix, desktop rice is
# profiles/desktop-linux.nix (which also carries the note system), toolkit is
# profiles/security.nix.
{ config, lib, ... }:
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
    # the plasma tablet session's terminal, riced: nu + starship + the theme
    # colorscheme instead of stock bash-on-white. minnow-only because only the
    # convertible runs the plasma session (rice.tablet.plasmaSession).
    ./modules/terminal/konsole.nix
    # nextcloud files sync + talk; calendar/contacts come via kde-pim's DAV
    # resource (see the module header for the one-time account logins).
    ./modules/desktop/nextcloud.nix
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

  # plasma's kde-gtk-config rewrites ~/.gtkrc-2.0 behind hm's back every tablet
  # session, turning the next switch into a backup collision once the .hm-backup
  # exists (hit 2026-08-04 and again 08-06). the file is generated on both
  # sides, so let hm overwrite it instead of backing it up. keyed via
  # configLocation: the gtk module registers the file under that absolute path,
  # a bare ".gtkrc-2.0" key would be a second entry on the same target. mkForce
  # because gtk2.nix pins force = false on its own entry.
  home.file.${config.gtk.gtk2.configLocation}.force = lib.mkForce true;

  # TODO(deploy): after first boot, read minnow's zen profile id out of
  # ~/.config/zen/profiles.ini and set rice.zen.profilePath here, otherwise the
  # zen transparency layer is a no-op on this box.
}
