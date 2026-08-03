# kdeconnect with working remote input on the niri rice (rice.kdeconnect.*),
# default OFF, switched on per host. programs.kdeconnect opens 1714-1764 tcp+udp
# so the phone can discover the box; the portal backend gives the mousepad
# plugin (phone as touchpad/keyboard) an actual input path, since niri ships no
# RemoteDesktop portal impl and kdeconnectd's portal calls would dead-end.
# deps: pkgs.wayland-kdeconnect-fix (pkgs/, additions overlay). the daemon +
# indicator run from the home layer (home/modules/desktop/kdeconnect.nix).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rice.kdeconnect;
in
{
  options.rice.kdeconnect.enable = lib.mkEnableOption "kdeconnect + remote-input portal bridge";

  config = lib.mkIf cfg.enable {
    programs.kdeconnect = {
      enable = true;
      # the same package the home service runs and the portal backend's caller
      # allowlist is patched against: three layers, one store path. mkDefault
      # because plasma6 (minnow's tablet session) defines the identical package
      # on this unique-typed option; if the two ever diverge, the portal
      # allowlist patch must follow whichever build actually runs.
      package = lib.mkDefault pkgs.kdePackages.kdeconnect-kde;
    };

    # ships the .portal file, the dbus service, and the systemd user unit;
    # extraPortals wires all three into where x-d-p and dbus actually look.
    xdg.portal.extraPortals = [ pkgs.wayland-kdeconnect-fix ];

    # backend routing is config-only on x-d-p 1.20 (UseIn is ignored). this
    # /etc/xdg entry shadows niri's shipped niri-portals.conf (datadir loses to
    # XDG_CONFIG_DIRS), so the gnome/gtk defaults must be replicated here, not
    # just the RemoteDesktop line. keep in sync with resources/niri-portals.conf
    # in the niri source if an update ever changes it.
    xdg.portal.config.niri = {
      default = [
        "gnome"
        "gtk"
      ];
      "org.freedesktop.impl.portal.Access" = "gtk";
      "org.freedesktop.impl.portal.Notification" = "gtk";
      "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
      "org.freedesktop.impl.portal.RemoteDesktop" = "hypr-kdeconnect";
    };
  };
}
