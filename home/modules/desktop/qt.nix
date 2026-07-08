# qt theming for the niri desktop (tuna): keep Qt apps (wireshark, pavucontrol's
# qt kin, RE tooling) from falling back to the light/alien Fusion default on a
# near-black rice. we mirror the GTK choice in niri.nix (adw-gtk3-dark for gtk3,
# gtk-application-prefer-dark-theme forced) rather than hand-rolling a second
# palette: less to drift out of sync, one dark source of truth.
#
# approach: platformTheme.name = "gtk3" makes Qt read GTK's settings (theme,
# fonts, file-picker) through the native Qt GTK3 plugin, so Qt follows the same
# adw-gtk3-dark GTK is already on. style.name = "adwaita-dark" then pins the
# actual widget style to Adwaita's dark variant (via adwaita-qt / adwaita-qt6,
# auto-pulled by the hm module from the style name), which guarantees dark chrome
# even where the GTK bridge only carries colors, not full styling. this pairing
# is the lowest-fragility coherent-dark result: no per-widget hex to maintain,
# and it tracks the GTK theme instead of the blood palette hex directly. we did
# NOT go the qtct route (qt5ct/qt6ct + kvantum) because that would mean owning a
# full second palette by hand for marginal control we don't need here.
#
# env: the hm qt module already emits QT_QPA_PLATFORMTHEME (-> "gtk3") and
# QT_STYLE_OVERRIDE (-> "adwaita-dark") into home.sessionVariables AND
# systemd.user.sessionVariables, so we do NOT set them by hand.
# CAVEAT(session): tuna's niri is greetd-spawned and spawns GUI apps directly
# (not through graphical-session.target), so neither of those env sources is
# guaranteed to reach a niri-launched Qt app. the real session env for niri
# lives in niri.nix `programs.niri.settings.environment` (do NOT edit here). if a
# Qt app still renders light after deploy, the fix is to add QT_QPA_PLATFORMTHEME
# = "gtk3" (and QT_STYLE_OVERRIDE = "adwaita-dark") to that niri env block; left
# unwired on purpose until observed, to avoid duplicating the module's own vars.
#
# cross-file deps: niri.nix owns the matching GTK theme (adw-gtk3-dark) + the
# session env block; theme.nix owns the blood palette (rice.theme.colors) that
# GTK, and by extension Qt, are colored to sit against.
{ lib, pkgs, ... }:
# linux-only insurance: imported solely from desktop-linux.nix today, but the
# hm qt module pulls linux-only Qt plugin packages, so a stray darwin import
# would break eval. cheap guard keeps that a no-op on the macs.
lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) {
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style.name = "adwaita-dark";
  };
}
