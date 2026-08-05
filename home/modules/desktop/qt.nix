# qt theming for the niri desktop: keep Qt apps (wireshark, pavucontrol's qt
# kin, RE tooling) from falling back to the light/alien Fusion default on a
# near-black rice. the adwaita style packages install HERE; the env pair that
# selects them (QT_QPA_PLATFORMTHEME=gtk3 + QT_STYLE_OVERRIDE=adwaita-dark)
# lives in niri.nix `programs.niri.settings.environment`, SESSION-scoped on
# purpose. do NOT hand these knobs back to the hm qt module: platformTheme.name
# / style.name write both vars into environment.d, which the systemd user
# manager loads for EVERY session, and a global QT_QPA_PLATFORMTHEME=gtk3 is
# fatal to plasma (rice.tablet.plasmaSession): kwin_wayland loads the qgtk3
# platform theme at startup, gtk_init finds no display (kwin IS the display,
# it does not exist yet) and exit(1)s the compositor before its first log
# line, while the kwin wrapper holds the session socket and respawns it
# forever. every plasma client then hangs on that socket: silent black screen,
# plasma-ksplash/kcminit start timeouts (minnow, 2026-08-04). NOT the qtct
# route (qt5ct/qt6ct + kvantum) either: that would mean owning a full second
# palette by hand.
#
# cross-file deps: niri.nix owns the matching GTK theme (adw-gtk3-dark) + the
# session env block that selects these styles; theme.nix owns the blood
# palette (rice.theme.colors) that GTK, and by extension Qt, sit against.
{ lib, pkgs, ... }:
# linux-only insurance: imported solely from desktop-linux.nix today, but the
# hm qt module pulls linux-only Qt plugin packages, so a stray darwin import
# would break eval. cheap guard keeps that a no-op on the macs.
lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) {
  # enable = plugin/qml path plumbing only (QT_PLUGIN_PATH / QML2_IMPORT_PATH),
  # so profile-installed style plugins resolve; theme selection stays session
  # env (see header).
  qt.enable = true;
  home.packages = [
    pkgs.adwaita-qt
    pkgs.adwaita-qt6
  ];
}
