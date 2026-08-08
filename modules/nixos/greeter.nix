# fleet greeter: SDDM (plasma's display manager) on wayland, themed with
# sddm-astronaut's hyprland_kath variant (owner pick 2026-08-07, replacing the
# stock breeze theme). one shared greeter for every linux host. niri is the
# default session; where plasma is installed (minnow's tablet posture,
# rice.tablet.plasmaSession) it appears as a selectable session.
#
# WHY here and not per-host: all three linux boxes want the identical greeter,
# so it lives in the shared nixos spine. defaultSession is a plain assignment
# (not mkDefault) on purpose: plasma6 (minnow's tablet session) sets
# defaultSession = mkDefault "plasma", and a mkDefault here would collide with
# it at equal priority. a plain "niri" outranks plasma6's mkDefault, so niri
# stays the default session everywhere without a per-host mkForce.
{ pkgs, ... }:
let
  kath = pkgs.sddm-astronaut.override { embeddedTheme = "hyprland_kath"; };

  # the theme draws a generic User.svg glyph next to the username, never the
  # account avatar, and azzie wants her actual profile picture at the door.
  # overlay the AccountsService icon for the selected user onto the indicator,
  # gated on Image.Ready so a box with no avatar set falls back to the stock
  # glyph instead of an empty square. --replace-fail so an upstream refactor of
  # Input.qml breaks the build loudly instead of silently shipping glyph-only.
  # postInstall, NOT postPatch: upstream's installPhase copies from $src, so a
  # patch-phase edit never reaches the output (verified 2026-08-07); and the
  # copy arrives store-read-only, hence the chmod.
  astronaut = kath.overrideAttrs (o: {
    postInstall = (o.postInstall or "") + ''
      chmod u+w "$out/share/sddm/themes/sddm-astronaut-theme/Components" \
        "$out/share/sddm/themes/sddm-astronaut-theme/Components/Input.qml"
      substituteInPlace "$out/share/sddm/themes/sddm-astronaut-theme/Components/Input.qml" \
        --replace-fail 'icon.source: Qt.resolvedUrl("../Assets/User.svg")' \
      'icon.source: faceIcon.status == Image.Ready ? "" : Qt.resolvedUrl("../Assets/User.svg")

              Image {
                  id: faceIcon
                  source: "file:///var/lib/AccountsService/icons/" + selectUser.currentValue
                  anchors.centerIn: parent
                  width: parent.height * 0.5
                  height: parent.height * 0.5
                  fillMode: Image.PreserveAspectCrop
                  visible: status == Image.Ready
              }'
    '';
  });
in
{
  services.displayManager = {
    sddm = {
      enable = true;
      # SDDM's own wayland greeter (no X server just to draw a login box).
      wayland.enable = true;
      theme = "sddm-astronaut-theme";
      # the qml runtime deps (qtmultimedia for the animated background, qtsvg,
      # qtvirtualkeyboard) propagate from the theme package; extraPackages puts
      # them on the greeter's import path.
      extraPackages = [ astronaut ];
    };
    defaultSession = "niri";
  };

  environment.systemPackages = [ astronaut ];

  # unlock gnome-keyring with the typed login password at the greeter: nothing
  # else on the sddm path unlocks it, and a locked org.freedesktop.secrets
  # collection is what wedged kwalletd6's event loop on minnow (the
  # element/signal 50s boot stall, 2026-08-07). honest limit: pam_u2f is
  # "sufficient" in this stack, so a fido-touch login yields no password and
  # the unlock only fires when the password is actually typed. kwallet's half
  # lives in tablet.nix, gated on the plasma session existing.
  security.pam.services.sddm.enableGnomeKeyring = true;
}
